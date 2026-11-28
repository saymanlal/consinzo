// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BeaconProxy.sol";

contract BoxV1 {
    error Refused(uint256 code);

    uint256 public slot0;
    uint256 public slot1;
    uint256 public received;

    function init(uint256 a) external payable {
        slot0 = a;
        received += msg.value;
    }

    function fill(uint256 a, uint256 b) external {
        slot0 = a;
        slot1 = b;
    }

    function refuse(uint256 code) external pure {
        revert Refused(code);
    }

    function echo(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }

    function sender() external view returns (address) {
        return msg.sender;
    }

    function tag() external pure virtual returns (string memory) {
        return "v1";
    }

    function readSlot(bytes32 slot) external view returns (bytes32 result) {
        assembly {
            result := sload(slot)
        }
    }

    receive() external payable {
        received += msg.value;
    }
}

contract BoxV2 is BoxV1 {
    function tag() external pure override returns (string memory) {
        return "v2";
    }
}

/// A beacon that is not an UpgradeableBeacon: the proxy must work with any IBeacon.
contract ToggleBeacon is IBeacon {
    address public first;
    address public second;
    bool public flipped;

    constructor(address first_, address second_) {
        first = first_;
        second = second_;
    }

    function flip() external {
        flipped = !flipped;
    }

    function implementation() external view returns (address) {
        return flipped ? second : first;
    }
}

contract BeaconProxyHiddenTest is Test {
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    BoxV1 public v1;
    BoxV2 public v2;
    UpgradeableBeacon public beacon;
    address public owner = address(0x0A11);
    address public user = address(0xA11CE);

    function setUp() public {
        v1 = new BoxV1();
        v2 = new BoxV2();
        beacon = new UpgradeableBeacon(address(v1), owner);
    }

    function _proxy(bytes memory initData) internal returns (BoxV1) {
        return BoxV1(payable(address(new BeaconProxy(address(beacon), initData))));
    }

    function testHiddenProxyStoresOnlyTheBeacon() public {
        BoxV1 p = _proxy(abi.encodeCall(BoxV1.init, (0)));
        for (uint256 i = 0; i < 6; i++) assertEq(p.readSlot(bytes32(i)), bytes32(0));
        assertEq(p.readSlot(IMPLEMENTATION_SLOT), bytes32(0));
        assertEq(p.readSlot(BEACON_SLOT), bytes32(uint256(uint160(address(beacon)))));

        // The implementation fills the low slots; the proxy keeps working.
        p.fill(type(uint256).max, type(uint256).max);
        assertEq(p.tag(), "v1");
        vm.prank(owner);
        beacon.upgradeTo(address(v2));
        assertEq(p.tag(), "v2");
        assertEq(p.slot0(), type(uint256).max);
        assertEq(p.readSlot(IMPLEMENTATION_SLOT), bytes32(0));
    }

    function testHiddenImplementationIsReadOnEveryCall() public {
        ToggleBeacon toggle = new ToggleBeacon(address(v1), address(v2));
        BoxV1 p = BoxV1(payable(address(new BeaconProxy(address(toggle), ""))));
        assertEq(p.tag(), "v1");
        toggle.flip();
        assertEq(p.tag(), "v2");
        toggle.flip();
        assertEq(p.tag(), "v1");
    }

    function testHiddenManyProxiesFollowTheBeacon() public {
        BoxV1[] memory proxies = new BoxV1[](5);
        for (uint256 i = 0; i < 5; i++) {
            proxies[i] = _proxy(abi.encodeCall(BoxV1.init, (i + 1)));
        }
        vm.prank(owner);
        beacon.upgradeTo(address(v2));
        for (uint256 i = 0; i < 5; i++) {
            assertEq(proxies[i].tag(), "v2");
            assertEq(proxies[i].slot0(), i + 1);
        }
        // A proxy created after the upgrade starts on the new implementation.
        assertEq(_proxy("").tag(), "v2");
    }

    function testHiddenBeaconUpgradeValidation() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(UpgradeableBeacon.NotContract.selector, address(0xBEEF)));
        beacon.upgradeTo(address(0xBEEF));

        vm.prank(user);
        vm.expectRevert(UpgradeableBeacon.NotOwner.selector);
        beacon.upgradeTo(address(v2));

        assertEq(beacon.implementation(), address(v1));
    }

    function testHiddenBeaconOwnershipTransfer() public {
        vm.prank(user);
        vm.expectRevert(UpgradeableBeacon.NotOwner.selector);
        beacon.transferOwnership(user);

        vm.prank(owner);
        vm.expectRevert(UpgradeableBeacon.ZeroAddress.selector);
        beacon.transferOwnership(address(0));

        vm.prank(owner);
        beacon.transferOwnership(user);
        assertEq(beacon.owner(), user);

        vm.prank(owner);
        vm.expectRevert(UpgradeableBeacon.NotOwner.selector);
        beacon.upgradeTo(address(v2));

        vm.prank(user);
        beacon.upgradeTo(address(v2));
        assertEq(beacon.implementation(), address(v2));
    }

    function testHiddenBeaconConstructorValidation() public {
        try new UpgradeableBeacon(address(v1), address(0)) {
            assertTrue(false, "zero owner accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), UpgradeableBeacon.ZeroAddress.selector);
        }
        try new UpgradeableBeacon(address(0xBEEF), owner) {
            assertTrue(false, "EOA implementation accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), UpgradeableBeacon.NotContract.selector);
        }
    }

    function testHiddenProxyConstructorValidation() public {
        try new BeaconProxy(address(0xBEEF), "") {
            assertTrue(false, "EOA beacon accepted");
        } catch (bytes memory err) {
            assertEq(keccak256(err), keccak256(abi.encodeWithSelector(BeaconProxy.NotContract.selector, address(0xBEEF))));
        }

        // A beacon whose implementation has no code.
        ToggleBeacon broken = new ToggleBeacon(address(0xDEAD), address(v1));
        try new BeaconProxy(address(broken), "") {
            assertTrue(false, "beacon with EOA implementation accepted");
        } catch (bytes memory err) {
            assertEq(keccak256(err), keccak256(abi.encodeWithSelector(BeaconProxy.NotContract.selector, address(0xDEAD))));
        }

        try new BeaconProxy(address(beacon), abi.encodeCall(BoxV1.refuse, (9))) {
            assertTrue(false, "failing initialiser accepted");
        } catch (bytes memory err) {
            assertEq(keccak256(err), keccak256(abi.encodeWithSelector(BoxV1.Refused.selector, uint256(9))));
        }
    }

    function testHiddenPassThroughOfDataSenderAndEther() public {
        BeaconProxy raw = new BeaconProxy{value: 1 ether}(address(beacon), abi.encodeCall(BoxV1.init, (4)));
        BoxV1 p = BoxV1(payable(address(raw)));
        assertEq(p.received(), 1 ether);
        assertEq(address(p).balance, 1 ether);

        vm.deal(user, 2 ether);
        vm.prank(user);
        (bool ok,) = address(p).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(p.received(), 3 ether);
        assertEq(address(p).balance, 3 ether);
        assertEq(address(v1).balance, 0);

        vm.prank(user);
        assertEq(p.sender(), user);

        bytes memory blob = new bytes(99);
        for (uint256 i = 0; i < blob.length; i++) blob[i] = bytes1(uint8(i + 3));
        assertEq(keccak256(p.echo(blob)), keccak256(blob));

        vm.expectRevert(abi.encodeWithSelector(BoxV1.Refused.selector, uint256(12)));
        p.refuse(12);
    }
}

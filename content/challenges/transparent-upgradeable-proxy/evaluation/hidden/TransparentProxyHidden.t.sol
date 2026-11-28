// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TransparentProxy.sol";

/// Implementation whose selectors clash with the proxy's management functions.
contract ClashingLogic {
    error Refused(uint256 code);

    uint256 public slot0;
    uint256 public slot1;
    uint256 public upgrades;
    uint256 public received;

    function admin() external pure returns (address) {
        return address(0xC1A5);
    }

    function implementation() external pure returns (address) {
        return address(0x1234);
    }

    function upgradeTo(address) external {
        upgrades += 1;
    }

    function changeAdmin(address) external {
        upgrades += 100;
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

    function readSlot(bytes32 slot) external view returns (bytes32 result) {
        assembly {
            result := sload(slot)
        }
    }

    receive() external payable {
        received += msg.value;
    }
}

contract PlainLogic {
    uint256 public slot0;
    uint256 public slot1;

    function bump() external payable {
        slot0 += 1;
    }

    function version() external pure returns (uint256) {
        return 9;
    }
}

contract TransparentProxyHiddenTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    ClashingLogic public logic;
    PlainLogic public plain;
    TransparentProxy public proxy;
    ClashingLogic public app;
    ITransparentProxy public management;
    address public admin = address(0xAD);
    address public user = address(0xA11CE);

    function setUp() public {
        logic = new ClashingLogic();
        plain = new PlainLogic();
        proxy = new TransparentProxy(address(logic), admin, "");
        app = ClashingLogic(payable(address(proxy)));
        management = ITransparentProxy(address(proxy));
    }

    function testHiddenClashingSelectorsResolveByCaller() public {
        // Non-admin: the implementation answers.
        vm.prank(user);
        assertEq(management.admin(), address(0xC1A5));
        vm.prank(user);
        assertEq(management.implementation(), address(0x1234));
        vm.prank(user);
        management.upgradeTo(address(plain));
        vm.prank(user);
        management.changeAdmin(user);
        assertEq(app.upgrades(), 101);

        // Admin: the proxy answers, and nothing was really upgraded or changed above.
        vm.prank(admin);
        assertEq(management.admin(), admin);
        vm.prank(admin);
        assertEq(management.implementation(), address(logic));
    }

    function testHiddenProxyUsesNoLowStorageSlots() public {
        assertEq(app.slot0(), 0);
        assertEq(app.slot1(), 0);
        for (uint256 i = 0; i < 6; i++) {
            assertEq(app.readSlot(bytes32(i)), bytes32(0));
        }
        app.fill(type(uint256).max, type(uint256).max);
        // Overwriting slots 0 and 1 must not disturb the proxy's bookkeeping.
        vm.prank(admin);
        assertEq(management.admin(), admin);
        vm.prank(admin);
        assertEq(management.implementation(), address(logic));
        assertEq(app.readSlot(IMPLEMENTATION_SLOT), bytes32(uint256(uint160(address(logic)))));
        assertEq(app.readSlot(ADMIN_SLOT), bytes32(uint256(uint160(admin))));
    }

    function testHiddenChangeAdmin() public {
        vm.prank(admin);
        management.changeAdmin(user);
        assertEq(app.readSlot(ADMIN_SLOT), bytes32(uint256(uint160(user))));

        // The old admin is an ordinary caller now: its call is delegated.
        vm.prank(admin);
        assertEq(management.admin(), address(0xC1A5));
        // The new admin is locked out of the implementation.
        vm.prank(user);
        vm.expectRevert(TransparentProxy.AdminCannotFallback.selector);
        app.fill(1, 2);
        vm.prank(user);
        assertEq(management.admin(), user);

        vm.prank(user);
        vm.expectRevert(TransparentProxy.ZeroAdmin.selector);
        management.changeAdmin(address(0));
    }

    function testHiddenUpgradeRejectsNonContracts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(TransparentProxy.NotContract.selector, address(0xBEEF)));
        management.upgradeTo(address(0xBEEF));

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(TransparentProxy.NotContract.selector, address(0)));
        management.upgradeToAndCall(address(0), "");

        vm.prank(admin);
        assertEq(management.implementation(), address(logic));
    }

    function testHiddenUpgradeToAndCall() public {
        app.fill(5, 6);
        vm.prank(admin);
        management.upgradeToAndCall(address(plain), abi.encodeCall(PlainLogic.bump, ()));

        PlainLogic upgraded = PlainLogic(address(proxy));
        assertEq(upgraded.version(), 9);
        assertEq(upgraded.slot0(), 6);
        assertEq(upgraded.slot1(), 6);
        assertEq(plain.slot0(), 0);
    }

    function testHiddenUpgradeToAndCallBubblesRevertAndRollsBack() public {
        ClashingLogic other = new ClashingLogic();
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ClashingLogic.Refused.selector, uint256(77)));
        management.upgradeToAndCall(address(other), abi.encodeCall(ClashingLogic.refuse, (77)));

        vm.prank(admin);
        assertEq(management.implementation(), address(logic));
    }

    function testHiddenReturnAndRevertDataPassThrough() public {
        bytes memory blob = new bytes(150);
        for (uint256 i = 0; i < blob.length; i++) blob[i] = bytes1(uint8(i * 7));
        assertEq(keccak256(app.echo(blob)), keccak256(blob));

        vm.expectRevert(abi.encodeWithSelector(ClashingLogic.Refused.selector, uint256(3)));
        app.refuse(3);

        vm.prank(user);
        assertEq(app.sender(), user);
    }

    function testHiddenEtherHandling() public {
        vm.deal(user, 3 ether);
        vm.prank(user);
        (bool ok,) = address(proxy).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(proxy).balance, 1 ether);
        assertEq(app.received(), 1 ether);

        // The admin cannot even send plain ether: that would hit the implementation.
        vm.deal(admin, 1 ether);
        vm.prank(admin);
        (ok,) = address(proxy).call{value: 1 ether}("");
        assertFalse(ok);
        assertEq(address(proxy).balance, 1 ether);
    }

    function testHiddenAdminUnknownSelectorReverts() public {
        vm.prank(admin);
        vm.expectRevert(TransparentProxy.AdminCannotFallback.selector);
        app.sender();
        vm.prank(admin);
        vm.expectRevert(TransparentProxy.AdminCannotFallback.selector);
        app.readSlot(ADMIN_SLOT);
    }

    function testHiddenConstructorValidationAndInitRevert() public {
        try new TransparentProxy(address(logic), address(0), "") {
            assertTrue(false, "zero admin accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), TransparentProxy.ZeroAdmin.selector);
        }
        try new TransparentProxy(address(0xBEEF), admin, "") {
            assertTrue(false, "EOA implementation accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), TransparentProxy.NotContract.selector);
        }
        try new TransparentProxy(address(logic), admin, abi.encodeCall(ClashingLogic.refuse, (5))) {
            assertTrue(false, "failing initialiser accepted");
        } catch (bytes memory err) {
            assertEq(keccak256(err), keccak256(abi.encodeWithSelector(ClashingLogic.Refused.selector, uint256(5))));
        }
    }
}

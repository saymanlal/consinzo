// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BeaconProxy.sol";

contract CounterV1 {
    error AlreadyInitialized();

    uint256 public count;
    address public creator;

    function initialize(uint256 start) external {
        if (creator != address(0)) revert AlreadyInitialized();
        creator = msg.sender;
        count = start;
    }

    function increment() external virtual {
        count += 1;
    }

    function version() external pure virtual returns (uint256) {
        return 1;
    }

    function readSlot(bytes32 slot) external view returns (bytes32 result) {
        assembly {
            result := sload(slot)
        }
    }
}

contract CounterV2 is CounterV1 {
    function increment() external override {
        count += 10;
    }

    function version() external pure override returns (uint256) {
        return 2;
    }
}

contract BeaconProxyTest is Test {
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    CounterV1 public v1;
    CounterV2 public v2;
    UpgradeableBeacon public beacon;
    CounterV1 public a;
    CounterV1 public b;
    CounterV1 public c;
    address public beaconOwner = address(0xB0055);

    function setUp() public {
        v1 = new CounterV1();
        v2 = new CounterV2();
        beacon = new UpgradeableBeacon(address(v1), beaconOwner);
        a = CounterV1(address(new BeaconProxy(address(beacon), abi.encodeCall(CounterV1.initialize, (1)))));
        b = CounterV1(address(new BeaconProxy(address(beacon), abi.encodeCall(CounterV1.initialize, (100)))));
        c = CounterV1(address(new BeaconProxy(address(beacon), "")));
    }

    function testBeaconState() public view {
        assertEq(beacon.owner(), beaconOwner);
        assertEq(beacon.implementation(), address(v1));
    }

    function testProxiesHaveSeparateState() public {
        a.increment();
        a.increment();
        b.increment();
        assertEq(a.count(), 3);
        assertEq(b.count(), 101);
        assertEq(c.count(), 0);
        assertEq(a.creator(), address(this));
        assertEq(c.creator(), address(0));
        assertEq(v1.count(), 0);
    }

    function testBeaconSlotHoldsBeacon() public view {
        assertEq(a.readSlot(BEACON_SLOT), bytes32(uint256(uint160(address(beacon)))));
        assertEq(c.readSlot(BEACON_SLOT), bytes32(uint256(uint160(address(beacon)))));
    }

    function testOneUpgradeSwitchesEveryProxy() public {
        a.increment();
        vm.prank(beaconOwner);
        beacon.upgradeTo(address(v2));

        assertEq(a.version(), 2);
        assertEq(b.version(), 2);
        assertEq(c.version(), 2);

        a.increment();
        b.increment();
        assertEq(a.count(), 12);
        assertEq(b.count(), 110);
    }

    function testOnlyOwnerUpgradesBeacon() public {
        vm.expectRevert(UpgradeableBeacon.NotOwner.selector);
        beacon.upgradeTo(address(v2));
        assertEq(a.version(), 1);
    }
}

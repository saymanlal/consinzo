// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TransparentProxy.sol";

contract LogicV1 {
    error AlreadyInitialized();

    uint256 public value;
    address public initializer;

    function initialize(uint256 v) external {
        if (initializer != address(0)) revert AlreadyInitialized();
        initializer = msg.sender;
        value = v;
    }

    function setValue(uint256 v) external {
        value = v;
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

contract LogicV2 is LogicV1 {
    function version() external pure override returns (uint256) {
        return 2;
    }

    function double() external {
        value *= 2;
    }
}

contract TransparentProxyTest is Test {
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    LogicV1 public v1;
    LogicV2 public v2;
    TransparentProxy public proxy;
    LogicV1 public app; // the proxy seen through the implementation ABI
    ITransparentProxy public management; // the proxy seen through the management ABI
    address public admin = address(0xAD);
    address public user = address(0xA11CE);

    function setUp() public {
        v1 = new LogicV1();
        v2 = new LogicV2();
        proxy = new TransparentProxy(address(v1), admin, abi.encodeCall(LogicV1.initialize, (42)));
        app = LogicV1(address(proxy));
        management = ITransparentProxy(address(proxy));
    }

    function testInitialisationRunsInProxyContext() public view {
        assertEq(app.value(), 42);
        assertEq(app.initializer(), address(this));
        // The implementation's own storage is untouched.
        assertEq(v1.value(), 0);
    }

    function testEip1967Slots() public view {
        assertEq(app.readSlot(IMPLEMENTATION_SLOT), bytes32(uint256(uint160(address(v1)))));
        assertEq(app.readSlot(ADMIN_SLOT), bytes32(uint256(uint160(admin))));
    }

    function testUserCallsAreDelegated() public {
        vm.prank(user);
        app.setValue(7);
        assertEq(app.value(), 7);
        assertEq(app.version(), 1);
    }

    function testAdminReadsManagementFunctions() public {
        vm.prank(admin);
        assertEq(management.admin(), admin);
        vm.prank(admin);
        assertEq(management.implementation(), address(v1));
    }

    function testUpgradeKeepsState() public {
        app.setValue(21);
        vm.prank(admin);
        management.upgradeTo(address(v2));

        assertEq(app.version(), 2);
        assertEq(app.value(), 21);
        LogicV2(address(proxy)).double();
        assertEq(app.value(), 42);
    }

    function testAdminCannotReachImplementation() public {
        vm.prank(admin);
        vm.expectRevert(TransparentProxy.AdminCannotFallback.selector);
        app.setValue(1);
    }

    function testNonAdminCannotUpgrade() public {
        // For a non-admin the call is delegated; LogicV1 has no upgradeTo, so it reverts.
        vm.prank(user);
        vm.expectRevert();
        management.upgradeTo(address(v2));
        assertEq(app.version(), 1);
    }
}

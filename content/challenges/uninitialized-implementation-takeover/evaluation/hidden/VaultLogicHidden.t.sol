// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VaultLogic.sol";

/// Records who called it. Used to detect foreign code running with a given identity.
contract Recorder {
    mapping(address => bool) public hit;

    function mark() external {
        hit[msg.sender] = true;
    }
}

/// Payload an attacker wants the implementation to delegatecall. On a chain where
/// SELFDESTRUCT still removes code, the second step would delete the implementation and
/// brick every proxy that points at it.
contract Wrecker {
    function wreck(Recorder recorder) external {
        recorder.mark();
        selfdestruct(payable(msg.sender));
    }
}

contract VaultLogicV2 is VaultLogic {
    function version() external pure returns (uint256) {
        return 2;
    }
}

/// Whole takeover in one transaction, from a contract.
contract Takeover {
    function run(VaultLogic logic, address payloadTarget, bytes calldata payload) external {
        try logic.initialize(address(this)) {} catch {}
        try logic.upgradeToAndCall(payloadTarget, payload) {} catch {}
    }
}

contract Migration {
    // Same layout as VaultLogic: slot 0 owner+initialized.
    address public owner;

    function setOwner(address newOwner) external {
        owner = newOwner;
    }

    function boom() external pure {
        revert("MIGRATION_FAILED");
    }
}

contract VaultLogicHiddenTest is Test {
    VaultLogic public logic;
    VaultLogic public vault;
    address public admin = address(0xAD);
    address public alice = address(0xA11CE);
    address public attacker = address(0xBAD);

    function setUp() public {
        logic = new VaultLogic();
        VaultProxy proxy = new VaultProxy(address(logic), abi.encodeWithSelector(VaultLogic.initialize.selector, admin));
        vault = VaultLogic(payable(address(proxy)));
        vm.deal(alice, 5 ether);
    }

    function testHiddenContractTakeoverFails() public {
        Recorder recorder = new Recorder();
        Wrecker wrecker = new Wrecker();
        Takeover t = new Takeover();
        t.run(logic, address(wrecker), abi.encodeWithSelector(Wrecker.wreck.selector, recorder));
        assertFalse(recorder.hit(address(logic)));
        assertTrue(logic.owner() != address(t));
        assertEq(logic.implementation(), address(0));
    }

    function testHiddenFreshImplementationsAreLockedToo() public {
        VaultLogic another = new VaultLogic();
        assertTrue(another.initialized());
        assertEq(another.owner(), address(0));
        vm.expectRevert(VaultLogic.AlreadyInitialized.selector);
        another.initialize(address(this));
        assertEq(another.owner(), address(0));
    }

    function testHiddenDirectUpgradeRevertsForEveryone() public {
        VaultLogicV2 v2 = new VaultLogicV2();
        vm.expectRevert();
        vm.prank(admin);
        logic.upgradeToAndCall(address(v2), "");
        assertEq(logic.implementation(), address(0));
    }

    function testHiddenSecondProxyInitialisesIndependently() public {
        VaultProxy p2 = new VaultProxy(address(logic), abi.encodeWithSelector(VaultLogic.initialize.selector, alice));
        VaultLogic v2 = VaultLogic(payable(address(p2)));
        assertEq(v2.owner(), alice);
        assertTrue(v2.initialized());
        assertEq(vault.owner(), admin);

        vm.expectRevert(VaultLogic.AlreadyInitialized.selector);
        vm.prank(attacker);
        v2.initialize(attacker);
        assertEq(v2.owner(), alice);
    }

    function testHiddenProxyCannotBeReinitialised() public {
        vm.expectRevert(VaultLogic.AlreadyInitialized.selector);
        vm.prank(attacker);
        vault.initialize(attacker);
        assertEq(vault.owner(), admin);
    }

    function testHiddenOnlyOwnerUpgradesProxy() public {
        VaultLogicV2 v2 = new VaultLogicV2();
        vm.expectRevert(VaultLogic.NotOwner.selector);
        vm.prank(attacker);
        vault.upgradeToAndCall(address(v2), "");
        assertEq(vault.implementation(), address(logic));
    }

    function testHiddenUpgradeWithMigrationCall() public {
        Migration m = new Migration();
        VaultLogicV2 v2 = new VaultLogicV2();
        vm.prank(alice);
        vault.deposit{value: 2 ether}();

        // A failing migration reverts the whole upgrade.
        vm.expectRevert(VaultLogic.UpgradeCallFailed.selector);
        vm.prank(admin);
        vault.upgradeToAndCall(address(m), abi.encodeWithSelector(Migration.boom.selector));
        assertEq(vault.implementation(), address(logic));

        vm.prank(admin);
        vault.upgradeToAndCall(address(v2), "");
        // The upgraded proxy can upgrade again and keeps its state.
        VaultLogicV2 v2b = new VaultLogicV2();
        vm.prank(admin);
        vault.upgradeToAndCall(address(v2b), "");
        assertEq(vault.implementation(), address(v2b));
        assertEq(vault.balanceOf(alice), 2 ether);
        vm.prank(alice);
        vault.withdraw(2 ether);
        assertEq(alice.balance, 5 ether);
    }

    function testHiddenUpgradeTargetMustBeContract() public {
        vm.expectRevert(VaultLogic.NotAContract.selector);
        vm.prank(admin);
        vault.upgradeToAndCall(address(0x1234), "");
        assertEq(vault.implementation(), address(logic));
    }
}

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

contract VaultLogicTest is Test {
    VaultLogic public logic; // the implementation contract
    VaultLogic public vault; // the proxy, seen through the logic ABI
    address public admin = address(0xAD);
    address public alice = address(0xA11CE);
    address public attacker = address(0xBAD);

    function setUp() public {
        logic = new VaultLogic();
        VaultProxy proxy = new VaultProxy(address(logic), abi.encodeWithSelector(VaultLogic.initialize.selector, admin));
        vault = VaultLogic(payable(address(proxy)));
        vm.deal(alice, 5 ether);
    }

    function testProxyIsInitialisedAndUsable() public {
        assertEq(vault.owner(), admin);
        assertEq(vault.implementation(), address(logic));
        vm.prank(alice);
        vault.deposit{value: 5 ether}();
        vm.prank(alice);
        vault.withdraw(2 ether);
        assertEq(vault.balanceOf(alice), 3 ether);
        assertEq(alice.balance, 2 ether);
        assertEq(address(vault).balance, 3 ether);
    }

    function testOwnerUpgradesThroughProxy() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();
        VaultLogicV2 v2 = new VaultLogicV2();
        vm.prank(admin);
        vault.upgradeToAndCall(address(v2), "");
        assertEq(vault.implementation(), address(v2));
        assertEq(VaultLogicV2(address(vault)).version(), 2);
        assertEq(vault.balanceOf(alice), 1 ether);
        assertEq(vault.owner(), admin);
    }

    function testImplementationCannotBeInitialised() public {
        vm.expectRevert(VaultLogic.AlreadyInitialized.selector);
        vm.prank(attacker);
        logic.initialize(attacker);
        assertEq(logic.owner(), address(0));
    }

    function testImplementationCannotBeMadeToRunForeignCode() public {
        Recorder recorder = new Recorder();
        Wrecker wrecker = new Wrecker();
        bytes memory payload = abi.encodeWithSelector(Wrecker.wreck.selector, recorder);

        vm.startPrank(attacker);
        (bool a, ) = address(logic).call(abi.encodeWithSelector(VaultLogic.initialize.selector, attacker));
        (bool b, ) = address(logic).call(
            abi.encodeWithSelector(VaultLogic.upgradeToAndCall.selector, address(wrecker), payload)
        );
        vm.stopPrank();
        a;
        b;

        assertFalse(recorder.hit(address(logic)));
        assertEq(logic.implementation(), address(0));
        // The proxy is unaffected.
        assertEq(vault.implementation(), address(logic));
        assertEq(vault.owner(), admin);
    }
}

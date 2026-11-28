// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PluginWallet.sol";

/// Attacker-supplied "plugin": rewrites slot 0 (owner) of whoever delegatecalls it.
contract TakeoverPlugin {
    function pwn(address newOwner) external {
        assembly {
            sstore(0, newOwner)
        }
    }
}

contract PluginWalletTest is Test {
    PluginWallet public wallet;
    BatchPayPlugin public batchPay;
    address public attacker = address(0xBAD);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        wallet = new PluginWallet{value: 10 ether}();
        batchPay = new BatchPayPlugin();
        wallet.setPlugin(address(batchPay), true);
    }

    function _payData(address a, uint256 x, address b, uint256 y) internal pure returns (bytes memory) {
        address payable[] memory to = new address payable[](2);
        uint256[] memory amounts = new uint256[](2);
        to[0] = payable(a);
        to[1] = payable(b);
        amounts[0] = x;
        amounts[1] = y;
        return abi.encodeWithSelector(BatchPayPlugin.pay.selector, to, amounts);
    }

    function testOwnerRunsApprovedPlugin() public {
        wallet.run(address(batchPay), _payData(alice, 1 ether, bob, 2 ether));
        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 2 ether);
        assertEq(address(wallet).balance, 7 ether);
        assertEq(wallet.owner(), address(this));
    }

    function testAttackerPluginCannotTakeOwnership() public {
        TakeoverPlugin evil = new TakeoverPlugin();
        bytes memory data = abi.encodeWithSelector(TakeoverPlugin.pwn.selector, attacker);
        vm.expectRevert();
        vm.prank(attacker);
        wallet.run(address(evil), data);
        assertEq(wallet.owner(), address(this));
    }

    function testStrangerCannotUseApprovedPlugin() public {
        bytes memory data = _payData(attacker, 5 ether, attacker, 5 ether);
        vm.expectRevert(PluginWallet.NotOwner.selector);
        vm.prank(attacker);
        wallet.run(address(batchPay), data);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testOwnerCannotRunUnapprovedPlugin() public {
        TakeoverPlugin other = new TakeoverPlugin();
        bytes memory data = abi.encodeWithSelector(TakeoverPlugin.pwn.selector, alice);
        vm.expectRevert(PluginWallet.PluginNotApproved.selector);
        wallet.run(address(other), data);
        assertEq(wallet.owner(), address(this));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PayoutBox.sol";

/// A contract wallet that can be told to reject incoming ETH.
contract PickyWallet {
    PayoutBox public box;
    bool public accepting;

    constructor(PayoutBox box_) {
        box = box_;
    }

    function setAccepting(bool value) external {
        accepting = value;
    }

    function deposit() external payable {
        box.deposit{value: msg.value}();
    }

    function withdraw() external {
        box.withdraw();
    }

    receive() external payable {
        require(accepting, "NOT_ACCEPTING");
    }
}

contract PayoutBoxTest is Test {
    PayoutBox public box;
    address public alice = address(0xA11CE);

    function setUp() public {
        box = new PayoutBox();
        vm.deal(alice, 5 ether);
    }

    function testDepositAndWithdraw() public {
        vm.prank(alice);
        box.deposit{value: 2 ether}();
        assertEq(box.balances(alice), 2 ether);

        vm.prank(alice);
        box.withdraw();
        assertEq(box.balances(alice), 0);
        assertEq(alice.balance, 5 ether);
    }

    function testFailedSendDoesNotWipeBalance() public {
        PickyWallet wallet = new PickyWallet(box);
        wallet.deposit{value: 1 ether}();

        // The wallet rejects ETH, so the payment fails and the withdrawal must revert.
        vm.expectRevert();
        wallet.withdraw();

        assertEq(box.balances(address(wallet)), 1 ether);
        assertEq(address(box).balance, 1 ether);
    }

    function testWithdrawalSucceedsOnceReceiverAccepts() public {
        PickyWallet wallet = new PickyWallet(box);
        wallet.deposit{value: 1 ether}();

        vm.expectRevert();
        wallet.withdraw();

        wallet.setAccepting(true);
        wallet.withdraw();
        assertEq(address(wallet).balance, 1 ether);
        assertEq(box.balances(address(wallet)), 0);
        assertEq(address(box).balance, 0);
    }

    function testNothingToWithdrawReverts() public {
        vm.prank(alice);
        vm.expectRevert(PayoutBox.NothingToWithdraw.selector);
        box.withdraw();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PayoutBox.sol";

/// Always rejects ETH and reports the raw outcome of withdraw().
contract RejectingWallet {
    PayoutBox public box;

    constructor(PayoutBox box_) {
        box = box_;
    }

    function deposit() external payable {
        box.deposit{value: msg.value}();
    }

    function tryWithdraw() external returns (bool ok, bytes memory data) {
        (ok, data) = address(box).call(abi.encodeCall(PayoutBox.withdraw, ()));
    }
}

/// A wallet whose receive function writes storage and therefore needs more than 2300 gas.
contract LedgerWallet {
    PayoutBox public box;
    uint256 public received;
    uint256 public payments;

    constructor(PayoutBox box_) {
        box = box_;
    }

    function deposit() external payable {
        box.deposit{value: msg.value}();
    }

    function withdraw() external {
        box.withdraw();
    }

    receive() external payable {
        received += msg.value;
        payments += 1;
    }
}

/// Re-enters withdraw() while being paid.
contract ReentrantWallet {
    PayoutBox public box;
    uint256 public reentries;

    constructor(PayoutBox box_) {
        box = box_;
    }

    function deposit() external payable {
        box.deposit{value: msg.value}();
    }

    function withdraw() external {
        box.withdraw();
    }

    receive() external payable {
        if (reentries < 2) {
            reentries++;
            try box.withdraw() {} catch {}
        }
    }
}

contract PayoutBoxHiddenTest is Test {
    PayoutBox public box;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        box = new PayoutBox();
        vm.deal(alice, 5 ether);
        vm.deal(bob, 5 ether);
        vm.prank(alice);
        box.deposit{value: 3 ether}();
    }

    function testHiddenFailureRevertsWithTransferFailed() public {
        RejectingWallet wallet = new RejectingWallet(box);
        wallet.deposit{value: 2 ether}();

        (bool ok, bytes memory data) = wallet.tryWithdraw();
        assertFalse(ok);
        assertEq(bytes32(data), bytes32(PayoutBox.TransferFailed.selector));
        assertEq(box.balances(address(wallet)), 2 ether);
        assertEq(address(box).balance, 5 ether);
    }

    function testHiddenStorageWritingReceiverIsPaid() public {
        LedgerWallet wallet = new LedgerWallet(box);
        wallet.deposit{value: 1 ether}();
        wallet.withdraw();
        assertEq(wallet.received(), 1 ether);
        assertEq(wallet.payments(), 1);
        assertEq(address(wallet).balance, 1 ether);
        assertEq(box.balances(address(wallet)), 0);
    }

    function testHiddenReentrantReceiverIsPaidOnce() public {
        ReentrantWallet wallet = new ReentrantWallet(box);
        wallet.deposit{value: 1 ether}();
        wallet.withdraw();
        assertEq(address(wallet).balance, 1 ether);
        assertEq(box.balances(address(wallet)), 0);
        // Alice's 3 ether is untouched.
        assertEq(address(box).balance, 3 ether);
        assertEq(box.balances(alice), 3 ether);
    }

    function testHiddenBalancesAreIndependent() public {
        vm.prank(bob);
        box.deposit{value: 1 ether}();
        vm.prank(bob);
        box.deposit{value: 1 ether}();
        assertEq(box.balances(bob), 2 ether);

        vm.prank(alice);
        box.withdraw();
        assertEq(alice.balance, 5 ether);
        assertEq(box.balances(bob), 2 ether);
        assertEq(address(box).balance, 2 ether);
    }

    function testHiddenSecondWithdrawReverts() public {
        vm.prank(alice);
        box.withdraw();
        vm.prank(alice);
        vm.expectRevert(PayoutBox.NothingToWithdraw.selector);
        box.withdraw();
    }

    function testHiddenZeroDepositRejected() public {
        vm.prank(bob);
        vm.expectRevert(PayoutBox.ZeroDeposit.selector);
        box.deposit{value: 0}();
    }
}

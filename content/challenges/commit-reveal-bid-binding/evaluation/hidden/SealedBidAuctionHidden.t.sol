// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SealedBidAuction.sol";

contract SealedBidAuctionHiddenTest is Test {
    SealedBidAuction internal auction;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal mallory = address(0xBAD);
    address internal seller = address(0x5E11E4);
    bytes32 internal constant SALT = keccak256("s1");

    function setUp() public {
        vm.prank(seller);
        auction = new SealedBidAuction(2 days, 1 days);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(mallory, 10 ether);
    }

    function testHiddenCommitmentFormula() public view {
        bytes32 expected = keccak256(abi.encode(address(auction), alice, uint256(123), SALT));
        assertEq(auction.computeCommitment(alice, 123, SALT), expected);
    }

    function testHiddenCommitmentIsBoundToAuctionInstance() public {
        SealedBidAuction other = new SealedBidAuction(2 days, 1 days);
        bytes32 a = auction.computeCommitment(alice, 1 ether, SALT);
        bytes32 b = other.computeCommitment(alice, 1 ether, SALT);
        assertTrue(a != b, "commitment must depend on the auction");
    }

    function testHiddenCopierLosesAndHonestBidderWinsTie() public {
        bytes32 c = auction.computeCommitment(alice, 4 ether, SALT);
        vm.prank(mallory);
        auction.commit{value: 9 ether}(c);
        vm.prank(alice);
        auction.commit{value: 4 ether}(c);
        vm.warp(block.timestamp + 2 days);

        vm.prank(mallory);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal(4 ether, SALT);
        vm.prank(alice);
        auction.reveal(4 ether, SALT);
        assertEq(auction.highestBidder(), alice);

        // The copier never revealed, so the whole deposit comes back and nothing more.
        vm.warp(block.timestamp + 1 days);
        vm.prank(mallory);
        auction.withdraw();
        assertEq(mallory.balance, 10 ether);
    }

    function testHiddenWrongSaltOrAmountReverts() public {
        bytes32 c = auction.computeCommitment(alice, 2 ether, SALT);
        vm.prank(alice);
        auction.commit{value: 3 ether}(c);
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal(2 ether, bytes32(uint256(1)));
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal(3 ether, SALT);
        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal(0, bytes32(0));
    }

    function testHiddenRevealRules() public {
        bytes32 c = auction.computeCommitment(alice, 5 ether, SALT);
        vm.prank(alice);
        auction.commit{value: 3 ether}(c);
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.BidExceedsDeposit.selector);
        auction.reveal(5 ether, SALT);

        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.WrongPhase.selector);
        auction.reveal(5 ether, SALT);
    }

    function testHiddenCommitRules() public {
        bytes32 c = auction.computeCommitment(alice, 1 ether, SALT);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.ZeroDeposit.selector);
        auction.commit(c);
        vm.prank(alice);
        auction.commit{value: 1 ether}(c);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.AlreadyCommitted.selector);
        auction.commit{value: 1 ether}(c);
        vm.warp(block.timestamp + 2 days);
        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.WrongPhase.selector);
        auction.commit{value: 1 ether}(c);
    }

    function testHiddenDoubleRevealReverts() public {
        bytes32 c = auction.computeCommitment(alice, 1 ether, SALT);
        vm.prank(alice);
        auction.commit{value: 1 ether}(c);
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        auction.reveal(1 ether, SALT);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.AlreadyRevealed.selector);
        auction.reveal(1 ether, SALT);
    }

    function testHiddenSettlementAmounts() public {
        bytes32 ca = auction.computeCommitment(alice, 3 ether, SALT);
        bytes32 cb = auction.computeCommitment(bob, 6 ether, SALT);
        vm.prank(alice);
        auction.commit{value: 3 ether}(ca);
        vm.prank(bob);
        auction.commit{value: 8 ether}(cb);
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        auction.reveal(3 ether, SALT);
        vm.prank(bob);
        auction.reveal(6 ether, SALT);

        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.WrongPhase.selector);
        auction.withdraw();

        vm.warp(block.timestamp + 1 days);
        vm.prank(bob);
        auction.withdraw();
        assertEq(bob.balance, 4 ether);
        vm.prank(bob);
        vm.expectRevert(SealedBidAuction.NothingToWithdraw.selector);
        auction.withdraw();
        vm.prank(alice);
        auction.withdraw();
        assertEq(alice.balance, 10 ether);

        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.NotSeller.selector);
        auction.claimProceeds();
        vm.prank(seller);
        auction.claimProceeds();
        assertEq(seller.balance, 6 ether);
        assertEq(address(auction).balance, 0);
        vm.prank(seller);
        vm.expectRevert(SealedBidAuction.NothingToWithdraw.selector);
        auction.claimProceeds();
    }
}

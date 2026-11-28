// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SealedBidAuction.sol";

contract SealedBidAuctionTest is Test {
    SealedBidAuction internal auction;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal mallory = address(0xBAD);
    bytes32 internal constant SALT = keccak256("alice-secret");

    function setUp() public {
        auction = new SealedBidAuction(1 days, 1 days);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(mallory, 10 ether);
    }

    function testCopiedCommitmentCannotBeRevealedByCopier() public {
        bytes32 c = auction.computeCommitment(alice, 5 ether, SALT);
        vm.prank(alice);
        auction.commit{value: 5 ether}(c);
        // Mallory copies the public commitment during the commit phase.
        vm.prank(mallory);
        auction.commit{value: 5 ether}(c);

        vm.warp(block.timestamp + 1 days);
        // Mallory sees Alice's pending reveal and front-runs it with the same values.
        vm.prank(mallory);
        vm.expectRevert(SealedBidAuction.InvalidReveal.selector);
        auction.reveal(5 ether, SALT);

        vm.prank(alice);
        auction.reveal(5 ether, SALT);
        assertEq(auction.highestBidder(), alice);
        assertEq(auction.highestBid(), 5 ether);
    }

    function testCommitmentIsBoundToBidder() public view {
        bytes32 a = auction.computeCommitment(alice, 1 ether, SALT);
        bytes32 m = auction.computeCommitment(mallory, 1 ether, SALT);
        assertTrue(a != m, "commitment must depend on the bidder");
    }

    function testHighestRevealWinsAndLoserIsRefunded() public {
        bytes32 ca = auction.computeCommitment(alice, 3 ether, SALT);
        bytes32 cb = auction.computeCommitment(bob, 2 ether, bytes32(uint256(7)));
        vm.prank(alice);
        auction.commit{value: 4 ether}(ca);
        vm.prank(bob);
        auction.commit{value: 2 ether}(cb);

        vm.warp(block.timestamp + 1 days);
        vm.prank(bob);
        auction.reveal(2 ether, bytes32(uint256(7)));
        vm.prank(alice);
        auction.reveal(3 ether, SALT);
        assertEq(auction.highestBidder(), alice);

        vm.warp(block.timestamp + 1 days);
        vm.prank(bob);
        auction.withdraw();
        assertEq(bob.balance, 10 ether);
        vm.prank(alice);
        auction.withdraw();
        assertEq(alice.balance, 7 ether);
    }

    function testRevealOutsideRevealPhaseReverts() public {
        bytes32 c = auction.computeCommitment(alice, 1 ether, SALT);
        vm.prank(alice);
        auction.commit{value: 1 ether}(c);
        vm.prank(alice);
        vm.expectRevert(SealedBidAuction.WrongPhase.selector);
        auction.reveal(1 ether, SALT);
    }
}

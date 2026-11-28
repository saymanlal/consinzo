// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EnglishAuction.sol";

/// Bidder that refuses every incoming ETH transfer.
contract StubbornBidder {
    EnglishAuction public auction;

    constructor(EnglishAuction _auction) payable {
        auction = _auction;
    }

    function placeBid(uint256 amount) external {
        auction.bid{value: amount}();
    }

    function pull() external {
        auction.withdraw();
    }

    receive() external payable {
        revert("no thanks");
    }
}

contract EnglishAuctionHiddenTest is Test {
    EnglishAuction public auction;
    address public seller = address(0x5E11E4);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    uint256 constant RESERVE = 1 ether;
    uint256 constant INCREMENT = 0.1 ether;
    uint256 constant DURATION = 1 days;
    uint256 constant WINDOW = 10 minutes;
    uint256 start;

    function setUp() public {
        vm.prank(seller);
        auction = new EnglishAuction(RESERVE, INCREMENT, DURATION, WINDOW);
        start = block.timestamp;
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
    }

    function testHiddenReserveBoundary() public {
        vm.prank(alice);
        vm.expectRevert(EnglishAuction.BidTooLow.selector);
        auction.bid{value: RESERVE - 1}();

        vm.prank(alice);
        auction.bid{value: RESERVE}();
        assertEq(auction.highestBid(), RESERVE);
    }

    function testHiddenIncrementBoundary() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();

        vm.prank(bob);
        vm.expectRevert(EnglishAuction.BidTooLow.selector);
        auction.bid{value: 1.1 ether - 1}();

        vm.prank(bob);
        auction.bid{value: 1.1 ether}();
        assertEq(auction.highestBidder(), bob);
        assertEq(auction.pendingReturns(alice), 1 ether);
    }

    function testHiddenBidAtEndTimeReverts() public {
        vm.warp(start + DURATION);
        vm.prank(alice);
        vm.expectRevert(EnglishAuction.AuctionEnded.selector);
        auction.bid{value: 1 ether}();
    }

    function testHiddenExtensionBoundary() public {
        // Exactly WINDOW seconds left: no extension.
        vm.warp(start + DURATION - WINDOW);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        assertEq(auction.endTime(), start + DURATION);

        // One second later: WINDOW - 1 seconds left, so the end moves by one second.
        vm.warp(start + DURATION - WINDOW + 1);
        vm.prank(bob);
        auction.bid{value: 2 ether}();
        assertEq(auction.endTime(), start + DURATION + 1);
    }

    function testHiddenRepeatedExtensions() public {
        vm.warp(start + DURATION - 1);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        uint256 end1 = start + DURATION - 1 + WINDOW;
        assertEq(auction.endTime(), end1);

        // The original end time has passed, but the auction is still live.
        vm.warp(end1 - 1);
        vm.expectRevert(EnglishAuction.AuctionNotEnded.selector);
        auction.settle();

        vm.prank(bob);
        auction.bid{value: 2 ether}();
        uint256 end2 = end1 - 1 + WINDOW;
        assertEq(auction.endTime(), end2);

        vm.warp(end2);
        vm.prank(carol);
        vm.expectRevert(EnglishAuction.AuctionEnded.selector);
        auction.bid{value: 3 ether}();

        auction.settle();
        assertEq(seller.balance, 2 ether);
        assertEq(auction.highestBidder(), bob);
    }

    function testHiddenRejectingBidderCanBeOutbid() public {
        StubbornBidder stubborn = new StubbornBidder{value: 5 ether}(auction);
        stubborn.placeBid(1 ether);
        assertEq(auction.highestBidder(), address(stubborn));

        vm.prank(alice);
        auction.bid{value: 2 ether}();
        assertEq(auction.highestBidder(), alice);
        assertEq(auction.pendingReturns(address(stubborn)), 1 ether);

        // Its own refund fails, and that is its own problem only.
        vm.expectRevert(EnglishAuction.TransferFailed.selector);
        stubborn.pull();
        assertEq(auction.pendingReturns(address(stubborn)), 1 ether);
    }

    function testHiddenLeaderRebidCreditsOldBid() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.prank(alice);
        auction.bid{value: 3 ether}();

        assertEq(auction.highestBid(), 3 ether);
        assertEq(auction.pendingReturns(alice), 1 ether);
        assertEq(address(auction).balance, 4 ether);
    }

    function testHiddenRefundsAccumulate() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.prank(bob);
        auction.bid{value: 2 ether}();
        vm.prank(alice);
        auction.bid{value: 3 ether}();
        vm.prank(bob);
        auction.bid{value: 4 ether}();
        vm.prank(alice);
        auction.bid{value: 5 ether}();

        assertEq(auction.pendingReturns(alice), 4 ether);
        assertEq(auction.pendingReturns(bob), 6 ether);

        vm.prank(bob);
        auction.withdraw();
        assertEq(bob.balance, 100 ether);

        vm.prank(bob);
        vm.expectRevert(EnglishAuction.NothingToWithdraw.selector);
        auction.withdraw();
    }

    function testHiddenSettleTwiceReverts() public {
        vm.prank(alice);
        auction.bid{value: 2 ether}();
        vm.warp(start + DURATION + 1);
        auction.settle();

        vm.expectRevert(EnglishAuction.AlreadySettled.selector);
        auction.settle();
        assertEq(seller.balance, 2 ether);
    }

    function testHiddenSettleWithoutBids() public {
        vm.warp(start + DURATION - 1);
        vm.expectRevert(EnglishAuction.AuctionNotEnded.selector);
        auction.settle();

        vm.warp(start + DURATION);
        auction.settle();
        assertTrue(auction.settled());
        assertEq(seller.balance, 0);
        assertEq(auction.highestBidder(), address(0));
    }

    function testHiddenEthConservation() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.prank(bob);
        auction.bid{value: 2 ether}();
        vm.prank(carol);
        auction.bid{value: 3 ether}();
        vm.warp(start + DURATION);

        // Losers can withdraw before or after settlement; settlement never touches their money.
        vm.prank(alice);
        auction.withdraw();
        auction.settle();
        assertEq(address(auction).balance, 2 ether);
        vm.prank(bob);
        auction.withdraw();

        assertEq(address(auction).balance, 0);
        assertEq(seller.balance, 3 ether);
        assertEq(alice.balance, 100 ether);
        assertEq(bob.balance, 100 ether);
        assertEq(carol.balance, 97 ether);

        vm.prank(carol);
        vm.expectRevert(EnglishAuction.NothingToWithdraw.selector);
        auction.withdraw();
    }
}

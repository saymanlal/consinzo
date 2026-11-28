// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EnglishAuction.sol";

contract EnglishAuctionTest is Test {
    EnglishAuction public auction;
    address public seller = address(0x5E11E4);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

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
    }

    function testInitialState() public view {
        assertEq(auction.seller(), seller);
        assertEq(auction.endTime(), start + DURATION);
        assertEq(auction.highestBidder(), address(0));
        assertEq(auction.highestBid(), 0);
        assertFalse(auction.settled());
    }

    function testBidsAndPullRefund() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        vm.prank(bob);
        auction.bid{value: 1.5 ether}();

        assertEq(auction.highestBidder(), bob);
        assertEq(auction.highestBid(), 1.5 ether);
        assertEq(auction.pendingReturns(alice), 1 ether);
        // Nothing was pushed back to Alice.
        assertEq(alice.balance, 99 ether);

        vm.prank(alice);
        auction.withdraw();
        assertEq(alice.balance, 100 ether);
        assertEq(auction.pendingReturns(alice), 0);
    }

    function testLowBidReverts() public {
        vm.prank(alice);
        auction.bid{value: 1 ether}();

        vm.prank(bob);
        vm.expectRevert(EnglishAuction.BidTooLow.selector);
        auction.bid{value: 1.05 ether}();
    }

    function testLateBidExtendsEndTime() public {
        vm.warp(start + DURATION - 1 minutes);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        assertEq(auction.endTime(), start + DURATION - 1 minutes + WINDOW);
    }

    function testEarlyBidDoesNotExtend() public {
        vm.warp(start + 1 hours);
        vm.prank(alice);
        auction.bid{value: 1 ether}();
        assertEq(auction.endTime(), start + DURATION);
    }

    function testSettlePaysSeller() public {
        vm.prank(alice);
        auction.bid{value: 2 ether}();
        vm.warp(start + DURATION);

        auction.settle();
        assertTrue(auction.settled());
        assertEq(seller.balance, 2 ether);
        assertEq(address(auction).balance, 0);
    }
}

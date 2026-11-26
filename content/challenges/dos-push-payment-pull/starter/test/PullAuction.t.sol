// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PullAuction.sol";

contract RevertingBidder {
    function placeBid(PullAuction a) external payable { a.bid{value: msg.value}(); }
    receive() external payable { revert("GRIEF"); }
}

contract PullAuctionTest is Test {
    function testRevertingBidderCannotBlockHigherBid() public {
        PullAuction auction = new PullAuction();
        RevertingBidder griefer = new RevertingBidder();
        griefer.placeBid{value: 1 ether}(auction);

        address honest = address(0xA11CE);
        vm.deal(honest, 5 ether);
        vm.prank(honest);
        auction.bid{value: 2 ether}();
        assertEq(auction.highestBidder(), honest);
        assertEq(auction.pendingReturns(address(griefer)), 1 ether);
    }
}
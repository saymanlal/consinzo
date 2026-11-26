// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/DutchAuction.sol";

contract DutchAuctionTest is Test {
    function testLinearDecayAndExcessRefund() public {
        address seller = address(0x555);
        vm.prank(seller);
        DutchAuction auction = new DutchAuction(10 ether, 2 ether, 800);
        vm.warp(block.timestamp + 400);
        assertEq(auction.currentPrice(), 6 ether);

        address buyer = address(0xB0B);
        vm.deal(buyer, 10 ether);
        vm.prank(buyer);
        auction.buy{value: 8 ether}();
        assertTrue(auction.sold());
        assertEq(buyer.balance, 4 ether);
        assertEq(seller.balance, 6 ether);
    }
}
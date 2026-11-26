// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/DutchAuction.sol";

contract DutchAuctionHiddenTest is Test {
    receive() external payable {}

    function testHiddenPriceFloorsAtReserveAndCannotDoubleBuy() public {
        DutchAuction a = new DutchAuction(10 ether, 2 ether, 100);
        vm.warp(block.timestamp + 500);
        assertEq(a.currentPrice(), 2 ether);
        address b = address(0xB0B);
        vm.deal(b, 5 ether);
        vm.prank(b); a.buy{value: 2 ether}();
        vm.prank(b); vm.expectRevert(); a.buy{value: 2 ether}();
    }
}
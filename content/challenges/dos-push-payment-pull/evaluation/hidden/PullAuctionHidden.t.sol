// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PullAuction.sol";

contract PullAuctionHiddenTest is Test {
    function testHiddenLegitimateWithdrawWorks() public {
        PullAuction a = new PullAuction();
        address u1 = address(0x111);
        address u2 = address(0x222);
        vm.deal(u1, 3 ether);
        vm.deal(u2, 3 ether);
        vm.prank(u1); a.bid{value: 1 ether}();
        vm.prank(u2); a.bid{value: 2 ether}();
        vm.prank(u1); a.withdrawRefund();
        assertEq(u1.balance, 3 ether);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/MilestoneEscrow.sol";

contract MilestoneEscrowTest is Test {
    address public buyer = address(0x111);
    address public seller = address(0x222);
    address public arbiter = address(0x333);

    function testBuyerApproveReleasesToSeller() public {
        vm.deal(buyer, 5 ether);
        vm.prank(buyer);
        MilestoneEscrow e = new MilestoneEscrow{value: 3 ether}(seller, arbiter);
        vm.prank(buyer);
        e.approveRelease();
        assertTrue(e.settled());
        assertEq(seller.balance, 3 ether);
    }

    function testArbiterRefundsBuyerOnDispute() public {
        vm.deal(buyer, 5 ether);
        vm.prank(buyer);
        MilestoneEscrow e = new MilestoneEscrow{value: 3 ether}(seller, arbiter);
        vm.prank(arbiter);
        e.resolveDispute(false);
        assertEq(buyer.balance, 5 ether);
    }
}
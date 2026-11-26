// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/MilestoneEscrow.sol";

contract MilestoneEscrowHiddenTest is Test {
    function testHiddenSellerCannotSelfRelease() public {
        MilestoneEscrow e = new MilestoneEscrow{value: 1 ether}(address(0x222), address(0x333));
        vm.prank(address(0x222));
        vm.expectRevert();
        e.approveRelease();
    }
}
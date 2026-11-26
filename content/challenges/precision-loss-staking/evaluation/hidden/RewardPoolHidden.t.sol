// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/RewardPool.sol";

contract RewardPoolHiddenTest is Test {
    function testHiddenZeroStakeReturnsZeroSafely() public {
        RewardPool p = new RewardPool(500 ether);
        assertEq(p.earned(address(0x123)), 0);
    }
}
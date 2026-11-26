// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/RewardPool.sol";

contract RewardPoolTest is Test {
    RewardPool public pool;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        pool = new RewardPool(1000 ether);
        vm.prank(alice); pool.deposit(100 ether);
        vm.prank(bob); pool.deposit(300 ether);
    }

    function testProportionalRewardsExact() public view {
        assertEq(pool.earned(alice), 250 ether);
        assertEq(pool.earned(bob), 750 ether);
    }
}
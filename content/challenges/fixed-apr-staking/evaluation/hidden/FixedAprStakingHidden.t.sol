// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FixedAprStaking.sol";

contract MockERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract FixedAprStakingHiddenTest is Test {
    MockERC20 public token;
    FixedAprStaking public staking;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new MockERC20();
        staking = new FixedAprStaking(address(token), 2000); // 20% APR
        token.mint(address(staking), 1_000 ether);
        token.mint(alice, 5_000 ether);
        token.mint(bob, 5_000 ether);
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);
    }

    function testHiddenStakingMoreCheckpointsFirst() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 73 days); // 1000 * 20% / 5 = 40
        vm.prank(alice);
        staking.stake(1_000 ether);
        assertEq(staking.pendingRewards(alice), 40 ether);
        vm.warp(block.timestamp + 73 days); // 2000 * 20% / 5 = 80
        assertEq(staking.pendingRewards(alice), 120 ether);
    }

    function testHiddenPartialUnstakeChangesRate() public {
        vm.prank(alice);
        staking.stake(2_000 ether);
        vm.warp(block.timestamp + 73 days); // 80
        vm.prank(alice);
        staking.unstake(1_500 ether);
        vm.warp(block.timestamp + 146 days); // 500 * 20% * 2/5 = 40
        assertEq(staking.pendingRewards(alice), 120 ether);
        assertEq(staking.stakedOf(alice), 500 ether);
    }

    function testHiddenNoCompounding() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        // Checkpoint many times with dust stakes; interest must stay simple.
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + 73 days);
            vm.prank(alice);
            staking.stake(1);
        }
        // one year at 20% on 1000 tokens, plus a negligible amount on the dust
        uint256 pending = staking.pendingRewards(alice);
        assertGe(pending, 200 ether - 5);
        assertLe(pending, 200 ether + 5);
    }

    function testHiddenStakersAreIndependent() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 73 days);
        vm.prank(bob);
        staking.stake(500 ether);
        vm.warp(block.timestamp + 73 days);
        assertEq(staking.pendingRewards(alice), 80 ether);
        assertEq(staking.pendingRewards(bob), 20 ether);
        vm.prank(bob);
        assertEq(staking.claim(), 20 ether);
        assertEq(staking.pendingRewards(alice), 80 ether);
        assertEq(staking.totalStaked(), 1_500 ether);
    }

    function testHiddenClaimCannotSpendPrincipal() public {
        vm.prank(alice);
        staking.stake(5_000 ether);
        vm.prank(bob);
        staking.stake(5_000 ether);
        vm.warp(block.timestamp + 2 * 365 days); // each earned 2000, pool holds 1000
        vm.prank(alice);
        vm.expectRevert(FixedAprStaking.InsufficientRewards.selector);
        staking.claim();
        assertEq(staking.rewardPool(), 1_000 ether);
        // principal is still fully withdrawable and rewards stay owed
        vm.prank(bob);
        staking.unstake(5_000 ether);
        assertEq(token.balanceOf(bob), 5_000 ether);
        assertEq(staking.pendingRewards(alice), 2_000 ether);
        // topping the pool up makes the claim succeed
        token.mint(address(staking), 1_000 ether);
        vm.prank(alice);
        assertEq(staking.claim(), 2_000 ether);
        assertEq(staking.rewardPool(), 0);
    }

    function testHiddenRevertPaths() public {
        vm.prank(alice);
        vm.expectRevert(FixedAprStaking.ZeroAmount.selector);
        staking.stake(0);
        vm.prank(alice);
        vm.expectRevert(FixedAprStaking.NothingToClaim.selector);
        staking.claim();
        vm.prank(alice);
        staking.stake(100 ether);
        vm.prank(alice);
        vm.expectRevert(FixedAprStaking.ZeroAmount.selector);
        staking.unstake(0);
        vm.prank(alice);
        vm.expectRevert(FixedAprStaking.InsufficientStake.selector);
        staking.unstake(100 ether + 1);
        vm.prank(bob);
        vm.expectRevert(FixedAprStaking.InsufficientStake.selector);
        staking.unstake(1);
    }

    function testHiddenInterestStopsAfterFullUnstake() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 365 days);
        vm.prank(alice);
        staking.unstake(1_000 ether);
        vm.warp(block.timestamp + 365 days);
        assertEq(staking.pendingRewards(alice), 200 ether);
    }
}

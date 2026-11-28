// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StakingRewards.sol";

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

contract StakingRewardsTest is Test {
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;
    StakingRewards public pool;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        stakingToken = new MockERC20();
        rewardsToken = new MockERC20();
        pool = new StakingRewards(address(stakingToken), address(rewardsToken), 1000);
        rewardsToken.mint(address(this), 100_000 ether);
        rewardsToken.approve(address(pool), type(uint256).max);
        stakingToken.mint(alice, 1_000 ether);
        stakingToken.mint(bob, 1_000 ether);
        vm.prank(alice);
        stakingToken.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(pool), type(uint256).max);
    }

    function testNotifySetsRateAndPeriod() public {
        pool.notifyRewardAmount(1_000 ether);
        assertEq(pool.rewardRate(), 1 ether);
        assertEq(pool.periodFinish(), block.timestamp + 1000);
        assertEq(pool.lastUpdateTime(), block.timestamp);
        assertEq(rewardsToken.balanceOf(address(pool)), 1_000 ether);
    }

    function testSingleStakerEarnsEverything() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        assertEq(pool.totalSupply(), 100 ether);
        vm.warp(block.timestamp + 100);
        assertEq(pool.rewardPerToken(), 1 ether);
        assertEq(pool.earned(alice), 100 ether);
    }

    function testTwoStakersShareProRata() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 100);
        vm.prank(bob);
        pool.stake(300 ether);
        vm.warp(block.timestamp + 100);
        assertEq(pool.earned(alice), 125 ether);
        assertEq(pool.earned(bob), 75 ether);
    }

    function testGetRewardPays() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 250);
        vm.prank(alice);
        uint256 paid = pool.getReward();
        assertEq(paid, 250 ether);
        assertEq(rewardsToken.balanceOf(alice), 250 ether);
        assertEq(pool.earned(alice), 0);
        assertEq(pool.balanceOf(alice), 100 ether);
    }

    function testWithdrawKeepsEarnedRewards() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 100);
        vm.prank(alice);
        pool.withdraw(100 ether);
        assertEq(stakingToken.balanceOf(alice), 1_000 ether);
        vm.warp(block.timestamp + 100);
        assertEq(pool.earned(alice), 100 ether);
    }
}

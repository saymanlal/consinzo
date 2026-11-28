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

contract StakingRewardsHiddenTest is Test {
    MockERC20 public stakingToken;
    MockERC20 public rewardsToken;
    StakingRewards public pool;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    function setUp() public {
        stakingToken = new MockERC20();
        rewardsToken = new MockERC20();
        pool = new StakingRewards(address(stakingToken), address(rewardsToken), 1000);
        rewardsToken.mint(address(this), 100_000 ether);
        rewardsToken.approve(address(pool), type(uint256).max);
        address[3] memory users = [alice, bob, carol];
        for (uint256 i = 0; i < 3; i++) {
            stakingToken.mint(users[i], 1_000 ether);
            vm.prank(users[i]);
            stakingToken.approve(address(pool), type(uint256).max);
        }
    }

    function testHiddenAccrualStopsAtPeriodFinish() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(50 ether);
        vm.warp(block.timestamp + 5000);
        assertEq(pool.lastTimeRewardApplicable(), pool.periodFinish());
        assertEq(pool.earned(alice), 1_000 ether);
        vm.prank(alice);
        pool.exit();
        assertEq(rewardsToken.balanceOf(alice), 1_000 ether);
        assertEq(stakingToken.balanceOf(alice), 1_000 ether);
        assertEq(rewardsToken.balanceOf(address(pool)), 0);
        assertEq(pool.totalSupply(), 0);
    }

    function testHiddenEarlyTopUpRollsOverLeftover() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 500);
        // 500 left + 1500 new = 2000 over a fresh 1000 s period
        pool.notifyRewardAmount(1_500 ether);
        assertEq(pool.rewardRate(), 2 ether);
        assertEq(pool.periodFinish(), block.timestamp + 1000);
        assertEq(pool.earned(alice), 500 ether);
        vm.warp(block.timestamp + 250);
        assertEq(pool.earned(alice), 1_000 ether);
        vm.warp(block.timestamp + 5000);
        assertEq(pool.earned(alice), 2_500 ether);
    }

    function testHiddenSecondPeriodAfterGap() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 3000); // first period over, 2000 s idle
        pool.notifyRewardAmount(4_000 ether);
        assertEq(pool.rewardRate(), 4 ether);
        vm.prank(bob);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 100);
        assertEq(pool.earned(alice), 1_200 ether);
        assertEq(pool.earned(bob), 200 ether);
    }

    function testHiddenNoRewardsWhileNobodyStaked() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.warp(block.timestamp + 400); // nobody staked for 400 s
        assertEq(pool.rewardPerToken(), 0);
        vm.prank(alice);
        pool.stake(10 ether);
        assertEq(pool.earned(alice), 0);
        vm.warp(block.timestamp + 600);
        assertEq(pool.earned(alice), 600 ether);
        vm.warp(block.timestamp + 600);
        assertEq(pool.earned(alice), 600 ether);
    }

    function testHiddenJoinLeaveSequence() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 100); // alice +100
        vm.prank(bob);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 100); // alice +50, bob +50
        vm.prank(carol);
        pool.stake(200 ether);
        vm.warp(block.timestamp + 100); // alice +25, bob +25, carol +50
        vm.prank(alice);
        pool.withdraw(100 ether);
        vm.warp(block.timestamp + 300); // bob +100, carol +200
        vm.prank(bob);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 400); // bob +200, carol +200
        assertEq(pool.earned(alice), 175 ether);
        assertEq(pool.earned(bob), 375 ether);
        assertEq(pool.earned(carol), 450 ether);

        vm.prank(alice);
        pool.getReward();
        vm.prank(bob);
        pool.exit();
        vm.prank(carol);
        pool.exit();
        assertEq(rewardsToken.balanceOf(alice), 175 ether);
        assertEq(rewardsToken.balanceOf(bob), 375 ether);
        assertEq(rewardsToken.balanceOf(carol), 450 ether);
        assertEq(rewardsToken.balanceOf(address(pool)), 0);
        assertEq(stakingToken.balanceOf(address(pool)), 0);
    }

    function testHiddenGetRewardTwicePaysOnce() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(100 ether);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        assertEq(pool.getReward(), 10 ether);
        vm.prank(alice);
        assertEq(pool.getReward(), 0);
        vm.prank(bob);
        assertEq(pool.getReward(), 0);
        vm.prank(bob);
        pool.exit(); // no stake, no rewards: must not revert
        assertEq(rewardsToken.balanceOf(alice), 10 ether);
    }

    function testHiddenRevertPaths() public {
        vm.prank(alice);
        vm.expectRevert(StakingRewards.NotOwner.selector);
        pool.notifyRewardAmount(1_000 ether);
        vm.expectRevert(StakingRewards.RewardTooSmall.selector);
        pool.notifyRewardAmount(999);
        vm.prank(alice);
        vm.expectRevert(StakingRewards.ZeroAmount.selector);
        pool.stake(0);
        vm.prank(alice);
        pool.stake(5 ether);
        vm.prank(alice);
        vm.expectRevert(StakingRewards.ZeroAmount.selector);
        pool.withdraw(0);
        vm.prank(alice);
        vm.expectRevert(StakingRewards.InsufficientBalance.selector);
        pool.withdraw(5 ether + 1);
    }

    function testHiddenRoundingNeverOverpays() public {
        pool.notifyRewardAmount(1_000 ether);
        vm.prank(alice);
        pool.stake(3);
        vm.prank(bob);
        pool.stake(7 ether + 1);
        vm.prank(carol);
        pool.stake(333 ether + 77);
        vm.warp(block.timestamp + 333);
        vm.prank(alice);
        pool.withdraw(1);
        vm.warp(block.timestamp + 5000);
        vm.prank(alice);
        pool.exit();
        vm.prank(bob);
        pool.exit();
        vm.prank(carol);
        pool.exit();
        uint256 paid = rewardsToken.balanceOf(alice) + rewardsToken.balanceOf(bob) + rewardsToken.balanceOf(carol);
        assertLe(paid, 1_000 ether);
        assertGe(paid, 1_000 ether - 1e6);
        assertEq(stakingToken.balanceOf(address(pool)), 0);
    }
}

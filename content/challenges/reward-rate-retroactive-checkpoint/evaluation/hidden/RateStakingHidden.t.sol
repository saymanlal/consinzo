// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RateStaking.sol";

contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        return true;
    }
}

contract RateStakingHiddenTest is Test {
    MockToken internal stakeToken;
    MockToken internal rewardToken;
    RateStaking internal pool;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        stakeToken = new MockToken();
        rewardToken = new MockToken();
        pool = new RateStaking(address(stakeToken), address(rewardToken), 2e18);
        _fund(alice, 300e18);
        _fund(bob, 300e18);
    }

    function _fund(address who, uint256 amount) internal {
        stakeToken.mint(who, amount);
        vm.prank(who);
        stakeToken.approve(address(pool), amount);
    }

    function testHiddenSeveralRateChangesAddUp() public {
        vm.prank(alice);
        pool.stake(50e18);
        vm.warp(block.timestamp + 100); // 100 s at 2
        pool.setRewardRate(7e18);
        vm.warp(block.timestamp + 10); // 10 s at 7
        pool.setRewardRate(1e18);
        vm.warp(block.timestamp + 30); // 30 s at 1
        pool.setRewardRate(0);
        vm.warp(block.timestamp + 999);
        pool.setRewardRate(3e18);
        vm.warp(block.timestamp + 5); // 5 s at 3
        assertEq(pool.earned(alice), 200e18 + 70e18 + 30e18 + 15e18);
    }

    function testHiddenTwoStakersSplitEachEraCorrectly() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 50); // alice alone: 100
        vm.prank(bob);
        pool.stake(300e18);
        vm.warp(block.timestamp + 100); // 200 total: alice 50, bob 150
        pool.setRewardRate(8e18);
        assertEq(pool.earned(alice), 150e18);
        assertEq(pool.earned(bob), 150e18);
        vm.warp(block.timestamp + 10); // 80 total: alice 20, bob 60
        assertEq(pool.earned(alice), 170e18);
        assertEq(pool.earned(bob), 210e18);
    }

    function testHiddenPoolFundedForTrueScheduleStaysSolvent() public {
        // 600 s at 2 then 100 s at 20 = 1200 + 2000 = 3200 tokens owed in total.
        rewardToken.mint(address(pool), 3200e18);
        vm.prank(alice);
        pool.stake(100e18);
        vm.prank(bob);
        pool.stake(100e18);
        vm.warp(block.timestamp + 600);
        pool.setRewardRate(20e18);
        vm.warp(block.timestamp + 100);
        pool.setRewardRate(0);

        vm.prank(alice);
        assertEq(pool.claim(), 1600e18);
        vm.prank(bob);
        assertEq(pool.claim(), 1600e18);
        assertEq(rewardToken.balanceOf(address(pool)), 0);
    }

    function testHiddenEmptyPoolTimeIsNeverPaid() public {
        vm.warp(block.timestamp + 1000);
        pool.setRewardRate(50e18);
        vm.warp(block.timestamp + 1000);
        vm.prank(alice);
        pool.stake(10e18);
        assertEq(pool.earned(alice), 0);
        vm.warp(block.timestamp + 2);
        assertEq(pool.earned(alice), 100e18);
    }

    function testHiddenRateChangeAfterFullExitDoesNotCreditLeaver() public {
        vm.prank(alice);
        pool.stake(10e18);
        vm.warp(block.timestamp + 10);
        vm.prank(alice);
        pool.withdraw(10e18);
        vm.warp(block.timestamp + 500);
        pool.setRewardRate(100e18);
        vm.warp(block.timestamp + 500);
        assertEq(pool.earned(alice), 20e18);
        // A later staker starts from zero as well.
        vm.prank(bob);
        pool.stake(1e18);
        assertEq(pool.earned(bob), 0);
    }

    function testHiddenSetRateUpdatesCheckpointState() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 25);
        pool.setRewardRate(4e18);
        assertEq(pool.lastUpdateTime(), block.timestamp);
        assertEq(pool.rewardPerTokenStored(), 5e17);
        assertEq(pool.rewardRate(), 4e18);
    }

    function testHiddenStakeWithdrawGuards() public {
        vm.prank(alice);
        vm.expectRevert(RateStaking.ZeroAmount.selector);
        pool.stake(0);
        vm.prank(alice);
        pool.stake(5e18);
        vm.prank(alice);
        vm.expectRevert(RateStaking.InsufficientStake.selector);
        pool.withdraw(6e18);
        vm.prank(alice);
        vm.expectRevert(RateStaking.ZeroAmount.selector);
        pool.withdraw(0);
        vm.prank(bob);
        vm.expectRevert(RateStaking.NotOwner.selector);
        pool.setRewardRate(0);
    }
}

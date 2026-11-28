// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/StreamedRewards.sol";

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

abstract contract PoolFixture is Test {
    uint256 internal constant WEEK = 7 days;
    uint256 internal constant REWARD = 604_800e18; // exactly 1 token per second for a week
    MockToken internal stakeToken;
    MockToken internal rewardToken;
    StreamedRewards internal pool;
    address internal distributor = address(0xD157);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal attacker = address(0xBAD);
    uint256 internal t;

    function _deploy() internal {
        t = block.timestamp;
        stakeToken = new MockToken();
        rewardToken = new MockToken();
        pool = new StreamedRewards(address(stakeToken), address(rewardToken), distributor);
        rewardToken.mint(distributor, 10 * REWARD);
        vm.prank(distributor);
        rewardToken.approve(address(pool), type(uint256).max);
        _fund(alice, 1000e18);
        _fund(bob, 1000e18);
        _fund(attacker, 100_000e18);
    }

    function _fund(address who, uint256 amount) internal {
        stakeToken.mint(who, amount);
        vm.prank(who);
        stakeToken.approve(address(pool), amount);
    }

    function _skip(uint256 secs) internal {
        t += secs;
        vm.warp(t);
    }

    function _stake(address who, uint256 amount) internal {
        vm.prank(who);
        pool.stake(amount);
    }

    function _notify(uint256 amount) internal {
        vm.prank(distributor);
        pool.notifyRewardAmount(amount);
    }
}

contract StreamedRewardsHiddenTest is PoolFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenOneBlockOfExposureEarnsOneBlockOfRewards() public {
        _stake(alice, 100e18);
        _stake(attacker, 900e18);
        _notify(REWARD);
        _skip(12);
        // 12 seconds at 1 token per second, 90% of the stake.
        assertEq(pool.earned(attacker), 10.8e18);
        vm.startPrank(attacker);
        pool.getReward();
        pool.withdraw(900e18);
        vm.stopPrank();
        _skip(WEEK);
        assertEq(pool.earned(alice), REWARD - 10.8e18);
    }

    function testHiddenSandwichingATopUpEarnsNothing() public {
        _stake(alice, 100e18);
        _notify(REWARD);
        _skip(2 days);
        uint256 aliceBefore = pool.earned(alice);
        _stake(attacker, 9900e18);
        _notify(REWARD);
        assertEq(pool.earned(attacker), 0);
        assertEq(pool.earned(alice), aliceBefore);
        vm.prank(attacker);
        pool.withdraw(9900e18);
        vm.prank(attacker);
        assertEq(pool.getReward(), 0);
    }

    function testHiddenNoAccrualAfterPeriodFinish() public {
        _stake(alice, 100e18);
        _notify(REWARD);
        _skip(WEEK + 30 days);
        assertEq(pool.lastTimeRewardApplicable(), pool.periodFinish());
        assertEq(pool.earned(alice), REWARD);
        // A late joiner gets nothing from the finished period.
        _stake(bob, 1000e18);
        _skip(1 days);
        assertEq(pool.earned(bob), 0);
        assertEq(pool.earned(alice), REWARD);
    }

    function testHiddenSplitByStakeAndTime() public {
        _stake(alice, 100e18);
        _notify(REWARD);
        _skip(WEEK / 2);
        _stake(bob, 100e18);
        _skip(WEEK / 2);
        assertEq(pool.earned(alice), (REWARD * 3) / 4);
        assertEq(pool.earned(bob), REWARD / 4);
    }

    function testHiddenNotifyWithNoStakersStartsTheStream() public {
        _notify(REWARD);
        assertEq(pool.rewardRate(), 1e18);
        _skip(1 days);
        _stake(alice, 5e18);
        assertEq(pool.earned(alice), 0);
        _skip(6 days);
        assertEq(pool.earned(alice), 6 * 86_400e18);
        _skip(1 days);
        assertEq(pool.earned(alice), 6 * 86_400e18);
    }

    function testHiddenNewPeriodAfterOldOneEnded() public {
        _stake(alice, 100e18);
        _notify(REWARD);
        _skip(WEEK + 1 days);
        _notify(2 * REWARD);
        assertEq(pool.rewardRate(), 2e18);
        assertEq(pool.periodFinish(), t + WEEK);
        assertEq(pool.earned(alice), REWARD);
        _skip(WEEK);
        assertEq(pool.earned(alice), 3 * REWARD);
        vm.prank(alice);
        assertEq(pool.getReward(), 3 * REWARD);
        assertEq(rewardToken.balanceOf(address(pool)), 0);
    }

    function testHiddenRateRoundsDownAndStaysSolvent() public {
        _stake(alice, 100e18);
        uint256 odd = 1_000_000e18 + 12345;
        _notify(odd);
        assertEq(pool.rewardRate(), odd / WEEK);
        assertLe(pool.rewardRate() * WEEK, rewardToken.balanceOf(address(pool)));
        _skip(3 days);
        _notify(777e18);
        uint256 leftover = 4 days * (odd / WEEK);
        assertEq(pool.rewardRate(), (777e18 + leftover) / WEEK);
        _skip(WEEK);
        vm.prank(alice);
        uint256 paid = pool.getReward();
        assertLe(paid, odd + 777e18);
        assertGe(paid, odd + 777e18 - 2e18);
    }

    function testHiddenGuards() public {
        vm.prank(distributor);
        vm.expectRevert(StreamedRewards.ZeroAmount.selector);
        pool.notifyRewardAmount(0);
        vm.prank(alice);
        vm.expectRevert(StreamedRewards.ZeroAmount.selector);
        pool.stake(0);
        _stake(alice, 10e18);
        vm.prank(alice);
        vm.expectRevert(StreamedRewards.InsufficientStake.selector);
        pool.withdraw(11e18);
        vm.prank(alice);
        pool.withdraw(10e18);
        assertEq(stakeToken.balanceOf(alice), 1000e18);
        assertEq(pool.totalStaked(), 0);
    }
}

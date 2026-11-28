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

contract StreamedRewardsTest is PoolFixture {
    function setUp() public {
        _deploy();
    }

    function testJustInTimeStakeEarnsNothing() public {
        _stake(alice, 100e18);
        _skip(30 days);

        // Sandwich: stake, notification, claim and withdraw, all in one block.
        _stake(attacker, 900e18);
        _notify(REWARD);
        assertEq(pool.earned(attacker), 0);
        vm.startPrank(attacker);
        uint256 paid = pool.getReward();
        pool.withdraw(900e18);
        vm.stopPrank();
        assertEq(paid, 0);
        assertEq(rewardToken.balanceOf(attacker), 0);

        // The staker who stays receives the stream.
        _skip(WEEK);
        assertEq(pool.earned(alice), REWARD);
    }

    function testRewardStreamsLinearly() public {
        _stake(alice, 100e18);
        _notify(REWARD);
        assertEq(pool.rewardRate(), 1e18);
        assertEq(pool.periodFinish(), t + WEEK);
        _skip(WEEK / 2);
        assertEq(pool.earned(alice), REWARD / 2);
        vm.prank(alice);
        assertEq(pool.getReward(), REWARD / 2);
        assertEq(rewardToken.balanceOf(alice), REWARD / 2);
    }

    function testTopUpRollsLeftoverIntoNewPeriod() public {
        _stake(alice, 100e18);
        _notify(REWARD);
        _skip(WEEK / 2);
        _notify(REWARD);
        // Half of the first reward is still undistributed: (1 + 0.5) weeks of tokens over one week.
        assertEq(pool.rewardRate(), 1.5e18);
        assertEq(pool.periodFinish(), t + WEEK);
        assertEq(pool.earned(alice), REWARD / 2);
    }

    function testOnlyDistributorNotifies() public {
        rewardToken.mint(attacker, 1e18);
        vm.prank(attacker);
        vm.expectRevert(StreamedRewards.NotDistributor.selector);
        pool.notifyRewardAmount(1e18);
    }
}

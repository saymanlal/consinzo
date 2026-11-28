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

contract RateStakingTest is Test {
    MockToken internal stakeToken;
    MockToken internal rewardToken;
    RateStaking internal pool;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        stakeToken = new MockToken();
        rewardToken = new MockToken();
        pool = new RateStaking(address(stakeToken), address(rewardToken), 1e18);
        _fund(alice, 100e18);
        _fund(bob, 100e18);
    }

    function _fund(address who, uint256 amount) internal {
        stakeToken.mint(who, amount);
        vm.prank(who);
        stakeToken.approve(address(pool), amount);
    }

    function testRateIncreaseIsNotRetroactive() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 1000);
        assertEq(pool.earned(alice), 1000e18);

        pool.setRewardRate(10e18);
        assertEq(pool.earned(alice), 1000e18, "past time must stay at the old rate");

        vm.warp(block.timestamp + 100);
        assertEq(pool.earned(alice), 2000e18);
    }

    function testRateDecreaseDoesNotClawBack() public {
        vm.prank(alice);
        pool.stake(100e18);
        vm.warp(block.timestamp + 500);
        pool.setRewardRate(0);
        assertEq(pool.earned(alice), 500e18, "earned rewards must survive a rate cut");
        vm.warp(block.timestamp + 5000);
        assertEq(pool.earned(alice), 500e18);
    }

    function testStakeAccrueAndClaim() public {
        rewardToken.mint(address(pool), 1000e18);
        vm.prank(alice);
        pool.stake(100e18);
        vm.prank(bob);
        pool.stake(100e18);
        vm.warp(block.timestamp + 200);
        vm.prank(alice);
        uint256 paid = pool.claim();
        assertEq(paid, 100e18);
        assertEq(rewardToken.balanceOf(alice), 100e18);
        assertEq(pool.earned(bob), 100e18);
    }

    function testOnlyOwnerSetsRate() public {
        vm.prank(alice);
        vm.expectRevert(RateStaking.NotOwner.selector);
        pool.setRewardRate(5e18);
    }
}

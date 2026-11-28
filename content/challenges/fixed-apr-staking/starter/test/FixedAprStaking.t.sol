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

contract FixedAprStakingTest is Test {
    MockERC20 public token;
    FixedAprStaking public staking;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new MockERC20();
        staking = new FixedAprStaking(address(token), 1000); // 10% APR
        token.mint(address(staking), 10_000 ether); // reward pool
        token.mint(alice, 5_000 ether);
        token.mint(bob, 5_000 ether);
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);
    }

    function testStakeMovesTokens() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        assertEq(staking.stakedOf(alice), 1_000 ether);
        assertEq(staking.totalStaked(), 1_000 ether);
        assertEq(token.balanceOf(alice), 4_000 ether);
        assertEq(staking.rewardPool(), 10_000 ether);
        assertEq(staking.pendingRewards(alice), 0);
    }

    function testInterestAfterOneYear() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 365 days);
        assertEq(staking.pendingRewards(alice), 100 ether);
    }

    function testInterestAfterPartialYear() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 73 days); // one fifth of a year
        assertEq(staking.pendingRewards(alice), 20 ether);
    }

    function testClaimPaysAndResets() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 365 days);
        vm.prank(alice);
        uint256 paid = staking.claim();
        assertEq(paid, 100 ether);
        assertEq(token.balanceOf(alice), 4_100 ether);
        assertEq(staking.pendingRewards(alice), 0);
        assertEq(staking.stakedOf(alice), 1_000 ether);
        assertEq(staking.rewardPool(), 9_900 ether);
    }

    function testUnstakeReturnsPrincipalOnly() public {
        vm.prank(alice);
        staking.stake(1_000 ether);
        vm.warp(block.timestamp + 365 days);
        vm.prank(alice);
        staking.unstake(1_000 ether);
        assertEq(token.balanceOf(alice), 5_000 ether);
        assertEq(staking.totalStaked(), 0);
        // rewards earned before unstaking are still claimable
        assertEq(staking.pendingRewards(alice), 100 ether);
    }
}

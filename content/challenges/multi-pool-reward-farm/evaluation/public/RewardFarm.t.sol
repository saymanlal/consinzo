// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RewardFarm.sol";

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

contract RewardFarmTest is Test {
    MockERC20 public reward;
    MockERC20 public lpA;
    MockERC20 public lpB;
    RewardFarm public farm;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    uint256 public t0;

    function setUp() public {
        t0 = block.timestamp;
        reward = new MockERC20();
        lpA = new MockERC20();
        lpB = new MockERC20();
        farm = new RewardFarm(address(reward), 10 ether, t0);
        reward.mint(address(farm), 1_000_000 ether);
        farm.add(100, address(lpA));
        farm.add(300, address(lpB));
        address[2] memory users = [alice, bob];
        for (uint256 i = 0; i < 2; i++) {
            lpA.mint(users[i], 1_000 ether);
            lpB.mint(users[i], 1_000 ether);
            vm.startPrank(users[i]);
            lpA.approve(address(farm), type(uint256).max);
            lpB.approve(address(farm), type(uint256).max);
            vm.stopPrank();
        }
    }

    function testPoolsRegistered() public view {
        assertEq(farm.poolLength(), 2);
        assertEq(farm.totalAllocPoint(), 400);
        (address lp, uint256 alloc, uint256 last, uint256 acc, uint256 staked) = farm.poolInfo(1);
        assertEq(lp, address(lpB));
        assertEq(alloc, 300);
        assertEq(last, t0);
        assertEq(acc, 0);
        assertEq(staked, 0);
    }

    function testSplitByAllocationPoints() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.prank(bob);
        farm.deposit(1, 100 ether);
        vm.warp(t0 + 100);
        // 1000 emitted: 25% to pool 0, 75% to pool 1
        assertEq(farm.pendingReward(0, alice), 250 ether);
        assertEq(farm.pendingReward(1, bob), 750 ether);
    }

    function testSplitByStakeInsidePool() public {
        vm.prank(alice);
        farm.deposit(1, 100 ether);
        vm.warp(t0 + 100); // alice 750
        vm.prank(bob);
        farm.deposit(1, 300 ether);
        vm.warp(t0 + 200); // 750 more: alice 187.5, bob 562.5
        assertEq(farm.pendingReward(1, alice), 937.5 ether);
        assertEq(farm.pendingReward(1, bob), 562.5 ether);
    }

    function testHarvestWithZeroDeposit() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.warp(t0 + 100);
        vm.prank(alice);
        farm.deposit(0, 0);
        assertEq(reward.balanceOf(alice), 250 ether);
        assertEq(farm.pendingReward(0, alice), 0);
        (uint256 amount, uint256 debt) = farm.userInfo(0, alice);
        assertEq(amount, 100 ether);
        assertEq(debt, 250 ether);
    }

    function testWithdrawPaysRewardAndStake() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.warp(t0 + 40);
        vm.prank(alice);
        farm.withdraw(0, 100 ether);
        assertEq(lpA.balanceOf(alice), 1_000 ether);
        assertEq(reward.balanceOf(alice), 100 ether);
        (, , , , uint256 staked) = farm.poolInfo(0);
        assertEq(staked, 0);
    }
}

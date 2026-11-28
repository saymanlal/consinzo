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

contract RewardFarmHiddenTest is Test {
    MockERC20 public reward;
    MockERC20 public lpA;
    MockERC20 public lpB;
    MockERC20 public lpC;
    RewardFarm public farm;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    uint256 public t0;

    function setUp() public {
        t0 = block.timestamp;
        reward = new MockERC20();
        lpA = new MockERC20();
        lpB = new MockERC20();
        lpC = new MockERC20();
        farm = new RewardFarm(address(reward), 10 ether, t0);
        reward.mint(address(farm), 1_000_000 ether);
        farm.add(100, address(lpA));
        farm.add(300, address(lpB));
        _fund(farm);
    }

    function _fund(RewardFarm f) internal {
        address[2] memory users = [alice, bob];
        MockERC20[3] memory lps = [lpA, lpB, lpC];
        for (uint256 i = 0; i < 2; i++) {
            for (uint256 j = 0; j < 3; j++) {
                lps[j].mint(users[i], 1_000 ether);
                vm.prank(users[i]);
                lps[j].approve(address(f), type(uint256).max);
            }
        }
    }

    function testHiddenSetIsNotRetroactive() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.prank(bob);
        farm.deposit(1, 100 ether);
        vm.warp(t0 + 100); // alice 250, bob 750
        farm.set(1, 100); // now 50/50
        assertEq(farm.totalAllocPoint(), 200);
        vm.warp(t0 + 200); // 500 each
        assertEq(farm.pendingReward(0, alice), 750 ether);
        assertEq(farm.pendingReward(1, bob), 1_250 ether);
        vm.prank(alice);
        farm.withdraw(0, 100 ether);
        vm.prank(bob);
        farm.withdraw(1, 100 ether);
        assertEq(reward.balanceOf(alice), 750 ether);
        assertEq(reward.balanceOf(bob), 1_250 ether);
    }

    function testHiddenAddIsNotRetroactive() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.warp(t0 + 100); // alice 250
        uint256 pid = farm.add(400, address(lpC)); // pool 0 now has 100 of 800
        assertEq(pid, 2);
        (, , uint256 last, , ) = farm.poolInfo(2);
        assertEq(last, t0 + 100);
        vm.prank(bob);
        farm.deposit(2, 50 ether);
        vm.warp(t0 + 180); // 800 emitted: alice 100, bob 400
        assertEq(farm.pendingReward(0, alice), 350 ether);
        assertEq(farm.pendingReward(2, bob), 400 ether);
    }

    function testHiddenNoRewardsBeforeStart() public {
        RewardFarm late = new RewardFarm(address(reward), 10 ether, t0 + 1000);
        reward.mint(address(late), 100_000 ether);
        late.add(1, address(lpA));
        (, , uint256 last, , ) = late.poolInfo(0);
        assertEq(last, t0 + 1000);
        _fund(late);
        vm.prank(alice);
        late.deposit(0, 10 ether);
        vm.warp(t0 + 500);
        assertEq(late.pendingReward(0, alice), 0);
        late.updatePool(0);
        vm.prank(alice);
        late.deposit(0, 0);
        assertEq(reward.balanceOf(alice), 0);
        vm.warp(t0 + 1100);
        assertEq(late.pendingReward(0, alice), 1_000 ether);
    }

    function testHiddenEmptyPoolTimeIsNotCredited() public {
        vm.warp(t0 + 500); // nobody staked for 500 s
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        assertEq(farm.pendingReward(0, alice), 0);
        vm.warp(t0 + 600);
        assertEq(farm.pendingReward(0, alice), 250 ether);
        vm.prank(alice);
        farm.withdraw(0, 100 ether);
        vm.warp(t0 + 900); // empty again
        vm.prank(bob);
        farm.deposit(0, 1 ether);
        vm.warp(t0 + 1000);
        assertEq(farm.pendingReward(0, bob), 250 ether);
        assertEq(farm.pendingReward(0, alice), 0);
    }

    function testHiddenEmergencyWithdrawForfeitsRewards() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.prank(bob);
        farm.deposit(0, 100 ether);
        vm.warp(t0 + 100); // 125 each
        vm.prank(alice);
        farm.emergencyWithdraw(0);
        assertEq(lpA.balanceOf(alice), 1_000 ether);
        assertEq(reward.balanceOf(alice), 0);
        (uint256 amount, uint256 debt) = farm.userInfo(0, alice);
        assertEq(amount, 0);
        assertEq(debt, 0);
        assertEq(farm.pendingReward(0, alice), 0);
        // bob is not credited with alice's forfeited share
        assertEq(farm.pendingReward(0, bob), 125 ether);
        vm.warp(t0 + 200);
        assertEq(farm.pendingReward(0, bob), 375 ether);
        // alice can come back with a clean slate
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        vm.warp(t0 + 300);
        assertEq(farm.pendingReward(0, alice), 125 ether);
    }

    function testHiddenPartialWithdrawAndRedeposit() public {
        vm.prank(alice);
        farm.deposit(1, 400 ether);
        vm.warp(t0 + 10); // 75
        vm.prank(alice);
        farm.withdraw(1, 300 ether);
        assertEq(reward.balanceOf(alice), 75 ether);
        vm.prank(bob);
        farm.deposit(1, 300 ether);
        vm.warp(t0 + 20); // 75 more: alice 18.75, bob 56.25
        vm.prank(alice);
        farm.deposit(1, 200 ether);
        assertEq(reward.balanceOf(alice), 93.75 ether);
        vm.warp(t0 + 30); // alice 300 of 600, bob 300 of 600
        assertEq(farm.pendingReward(1, alice), 37.5 ether);
        assertEq(farm.pendingReward(1, bob), 93.75 ether);
        (uint256 amount, ) = farm.userInfo(1, alice);
        assertEq(amount, 300 ether);
        (, , , , uint256 staked) = farm.poolInfo(1);
        assertEq(staked, 600 ether);
    }

    function testHiddenAccessControlAndValidation() public {
        vm.prank(alice);
        vm.expectRevert(RewardFarm.NotOwner.selector);
        farm.add(10, address(lpC));
        vm.prank(alice);
        vm.expectRevert(RewardFarm.NotOwner.selector);
        farm.set(0, 10);
        vm.expectRevert(RewardFarm.DuplicatePool.selector);
        farm.add(10, address(lpA));
        vm.expectRevert(RewardFarm.InvalidPool.selector);
        farm.set(2, 10);
        vm.expectRevert(RewardFarm.InvalidPool.selector);
        farm.updatePool(2);
        vm.expectRevert(RewardFarm.InvalidPool.selector);
        farm.pendingReward(2, alice);
        vm.prank(alice);
        vm.expectRevert(RewardFarm.InvalidPool.selector);
        farm.deposit(2, 1 ether);
        vm.prank(alice);
        vm.expectRevert(RewardFarm.InvalidPool.selector);
        farm.withdraw(2, 0);
        vm.prank(alice);
        vm.expectRevert(RewardFarm.InvalidPool.selector);
        farm.emergencyWithdraw(2);
        vm.prank(alice);
        farm.deposit(0, 5 ether);
        vm.prank(alice);
        vm.expectRevert(RewardFarm.InsufficientBalance.selector);
        farm.withdraw(0, 5 ether + 1);
        vm.prank(bob);
        vm.expectRevert(RewardFarm.InsufficientBalance.selector);
        farm.withdraw(0, 1);
    }

    function testHiddenDonatedLpDoesNotDilute() public {
        vm.prank(alice);
        farm.deposit(0, 100 ether);
        lpA.mint(address(farm), 900 ether); // direct transfer, not a deposit
        vm.warp(t0 + 100);
        assertEq(farm.pendingReward(0, alice), 250 ether);
    }

    function testHiddenZeroAllocPoolEarnsNothingAndTotalIsBounded() public {
        vm.prank(alice);
        farm.deposit(0, 3);
        vm.prank(bob);
        farm.deposit(1, 7 ether + 1);
        vm.warp(t0 + 33);
        farm.set(0, 0);
        vm.prank(bob);
        farm.deposit(0, 11 ether);
        vm.warp(t0 + 77);
        vm.prank(alice);
        farm.deposit(1, 13 ether + 5);
        vm.warp(t0 + 150);
        farm.massUpdatePools();
        uint256 before = reward.balanceOf(address(farm));
        vm.prank(alice);
        farm.withdraw(0, 3);
        vm.prank(alice);
        farm.withdraw(1, 13 ether + 5);
        vm.prank(bob);
        farm.withdraw(0, 11 ether);
        vm.prank(bob);
        farm.withdraw(1, 7 ether + 1);
        // bob never earned anything in pool 0 after its points were set to zero
        uint256 paid = before - reward.balanceOf(address(farm));
        assertLe(paid, 1_500 ether);
        assertGe(paid, 1_500 ether - 1e6);
        // alice in pool 0: 33 s at 25% = 82.5
        assertLe(reward.balanceOf(alice), 82.5 ether + 73 * 7.5 ether);
        assertGe(reward.balanceOf(alice), 82.5 ether - 1e6);
    }
}

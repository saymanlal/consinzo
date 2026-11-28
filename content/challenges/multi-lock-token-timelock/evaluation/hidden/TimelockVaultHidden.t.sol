// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TimelockVault.sol";

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

contract TimelockVaultHiddenTest is Test {
    MockERC20 public token;
    TimelockVault public vault;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    uint256 public start;

    function setUp() public {
        token = new MockERC20();
        vault = new TimelockVault(address(token));
        token.mint(alice, 1_000 ether);
        token.mint(bob, 1_000 ether);
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);
        start = block.timestamp;
    }

    function testHiddenLockValidation() public {
        vm.prank(alice);
        vm.expectRevert(TimelockVault.ZeroAmount.selector);
        vault.lock(0, start + 100);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.InvalidUnlockTime.selector);
        vault.lock(1 ether, start);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.InvalidUnlockTime.selector);
        vault.lock(1 ether, start - 1);
        vm.prank(alice);
        assertEq(vault.lock(1 ether, start + 1), 0);
    }

    function testHiddenNoDoubleWithdraw() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 10);
        vm.prank(bob);
        vault.lock(500 ether, start + 10);
        vm.warp(start + 10);
        vm.prank(alice);
        vault.withdraw(0);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.AlreadyWithdrawn.selector);
        vault.withdraw(0);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.NothingToWithdraw.selector);
        vault.withdrawMatured();
        assertEq(token.balanceOf(address(vault)), 500 ether);
        assertEq(vault.totalLocked(), 500 ether);
        assertEq(vault.lockedBalance(alice), 0);
        assertEq(vault.withdrawableBalance(alice), 0);
    }

    function testHiddenUsersAreIsolated() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 10);
        vm.prank(bob);
        vault.lock(200 ether, start + 1000);
        vm.warp(start + 10);
        // bob's lock 0 is his own, not alice's
        vm.prank(bob);
        vm.expectRevert(TimelockVault.StillLocked.selector);
        vault.withdraw(0);
        vm.prank(bob);
        vm.expectRevert(TimelockVault.InvalidLock.selector);
        vault.withdraw(1);
        vm.prank(bob);
        vm.expectRevert(TimelockVault.NothingToWithdraw.selector);
        vault.withdrawMatured();
        vm.prank(bob);
        vm.expectRevert(TimelockVault.InvalidLock.selector);
        vault.extendLock(3, start + 5000);
        vm.expectRevert(TimelockVault.InvalidLock.selector);
        vault.getLock(alice, 1);
        assertEq(vault.withdrawableBalance(alice), 100 ether);
        assertEq(vault.withdrawableBalance(bob), 0);
    }

    function testHiddenExtendRules() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 100);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.InvalidUnlockTime.selector);
        vault.extendLock(0, start + 100);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.InvalidUnlockTime.selector);
        vault.extendLock(0, start + 99);

        // a matured lock can be re-locked, but only into the future
        vm.warp(start + 500);
        assertEq(vault.withdrawableBalance(alice), 100 ether);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.InvalidUnlockTime.selector);
        vault.extendLock(0, start + 500);
        vm.prank(alice);
        vault.extendLock(0, start + 501);
        assertEq(vault.withdrawableBalance(alice), 0);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.StillLocked.selector);
        vault.withdraw(0);

        vm.warp(start + 501);
        vm.prank(alice);
        vault.withdraw(0);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.AlreadyWithdrawn.selector);
        vault.extendLock(0, start + 9000);
    }

    function testHiddenBatchSkipsWithdrawnAndImmature() public {
        uint256[5] memory offsets = [uint256(50), 100, 150, 2000, 200];
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            vault.lock((i + 1) * 10 ether, start + offsets[i]);
        }
        vm.warp(start + 150);
        vm.prank(alice);
        vault.withdraw(1); // 20
        vm.warp(start + 200);
        assertEq(vault.withdrawableBalance(alice), 90 ether); // 10 + 30 + 50
        vm.prank(alice);
        assertEq(vault.withdrawMatured(), 90 ether);
        assertEq(token.balanceOf(alice), 1_000 ether - 40 ether);
        assertEq(vault.lockedBalance(alice), 40 ether);
        assertEq(vault.totalLocked(), 40 ether);
        // ids are stable
        (uint256 amount, uint256 unlockTime, bool withdrawn) = vault.getLock(alice, 3);
        assertEq(amount, 40 ether);
        assertEq(unlockTime, start + 2000);
        assertFalse(withdrawn);
        (amount, , withdrawn) = vault.getLock(alice, 4);
        assertEq(amount, 50 ether);
        assertTrue(withdrawn);
        assertEq(vault.lockCount(alice), 5);
    }

    function testHiddenExactBoundary() public {
        vm.prank(alice);
        vault.lock(7 ether, start + 60);
        vm.warp(start + 59);
        assertEq(vault.withdrawableBalance(alice), 0);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.StillLocked.selector);
        vault.withdraw(0);
        vm.warp(start + 60);
        assertEq(vault.withdrawableBalance(alice), 7 ether);
        vm.prank(alice);
        vault.withdraw(0);
        assertEq(token.balanceOf(alice), 1_000 ether);
    }
}

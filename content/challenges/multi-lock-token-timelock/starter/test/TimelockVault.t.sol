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

contract TimelockVaultTest is Test {
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

    function testLockCreatesIndependentEntries() public {
        vm.prank(alice);
        uint256 id0 = vault.lock(100 ether, start + 100);
        vm.prank(alice);
        uint256 id1 = vault.lock(250 ether, start + 500);
        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(vault.lockCount(alice), 2);
        (uint256 amount, uint256 unlockTime, bool withdrawn) = vault.getLock(alice, 1);
        assertEq(amount, 250 ether);
        assertEq(unlockTime, start + 500);
        assertFalse(withdrawn);
        assertEq(vault.lockedBalance(alice), 350 ether);
        assertEq(vault.totalLocked(), 350 ether);
        assertEq(token.balanceOf(address(vault)), 350 ether);
    }

    function testWithdrawAfterUnlock() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 100);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.StillLocked.selector);
        vault.withdraw(0);
        vm.warp(start + 100);
        vm.prank(alice);
        vault.withdraw(0);
        assertEq(token.balanceOf(alice), 1_000 ether);
        assertEq(vault.totalLocked(), 0);
        (, , bool withdrawn) = vault.getLock(alice, 0);
        assertTrue(withdrawn);
    }

    function testLocksMatureIndependently() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 100);
        vm.prank(alice);
        vault.lock(250 ether, start + 500);
        vm.warp(start + 200);
        assertEq(vault.withdrawableBalance(alice), 100 ether);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.StillLocked.selector);
        vault.withdraw(1);
        vm.prank(alice);
        vault.withdraw(0);
        assertEq(vault.lockedBalance(alice), 250 ether);
    }

    function testExtendLock() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 100);
        vm.prank(alice);
        vault.extendLock(0, start + 300);
        vm.warp(start + 200);
        vm.prank(alice);
        vm.expectRevert(TimelockVault.StillLocked.selector);
        vault.withdraw(0);
        vm.warp(start + 300);
        vm.prank(alice);
        vault.withdraw(0);
        assertEq(token.balanceOf(alice), 1_000 ether);
    }

    function testWithdrawMatured() public {
        vm.prank(alice);
        vault.lock(100 ether, start + 100);
        vm.prank(alice);
        vault.lock(200 ether, start + 200);
        vm.prank(alice);
        vault.lock(300 ether, start + 900);
        vm.warp(start + 250);
        vm.prank(alice);
        uint256 total = vault.withdrawMatured();
        assertEq(total, 300 ether);
        assertEq(token.balanceOf(alice), 700 ether);
        assertEq(vault.lockedBalance(alice), 300 ether);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PausableToken.sol";

contract PausableTokenHiddenTest is Test {
    PausableToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new PausableToken();
        token.mint(alice, 1000);
    }

    function testHiddenPauseStateMachine() public {
        vm.expectRevert(PausableToken.ExpectedPause.selector);
        token.unpause();

        token.pause();
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.pause();
        assertTrue(token.paused());

        token.unpause();
        vm.expectRevert(PausableToken.ExpectedPause.selector);
        token.unpause();
        assertFalse(token.paused());

        token.pause();
        assertTrue(token.paused());
    }

    function testHiddenOnlyOwnerUnpausesAndOwnerCheckFirst() public {
        // Not paused and not owner: the owner check is reported.
        vm.prank(alice);
        vm.expectRevert(PausableToken.NotOwner.selector);
        token.unpause();

        token.pause();
        vm.prank(alice);
        vm.expectRevert(PausableToken.NotOwner.selector);
        token.unpause();
        vm.prank(alice);
        vm.expectRevert(PausableToken.NotOwner.selector);
        token.pause();
        assertTrue(token.paused());
    }

    function testHiddenTransferFromBlockedWhilePausedAndAllowanceKept() public {
        vm.prank(alice);
        token.approve(bob, 300);
        token.pause();

        vm.prank(bob);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.transferFrom(alice, bob, 100);

        assertEq(token.allowance(alice, bob), 300);
        assertEq(token.balanceOf(alice), 1000);

        token.unpause();
        vm.prank(bob);
        token.transferFrom(alice, bob, 100);
        assertEq(token.allowance(alice, bob), 200);
        assertEq(token.balanceOf(bob), 100);
    }

    function testHiddenBurnBlockedWhilePaused() public {
        token.pause();
        vm.prank(alice);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.burn(10);
        assertEq(token.totalSupply(), 1000);

        token.unpause();
        vm.prank(alice);
        token.burn(10);
        assertEq(token.totalSupply(), 990);
        assertEq(token.balanceOf(alice), 990);
    }

    function testHiddenMintAllowedWhilePaused() public {
        token.pause();
        token.mint(bob, 500);
        assertEq(token.balanceOf(bob), 500);
        assertEq(token.totalSupply(), 1500);

        vm.prank(alice);
        vm.expectRevert(PausableToken.NotOwner.selector);
        token.mint(alice, 1);

        // Minted tokens are still frozen for the holder until unpause.
        vm.prank(bob);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.transfer(alice, 1);
    }

    function testHiddenApproveAllowedWhilePaused() public {
        vm.prank(alice);
        token.approve(bob, 400);
        token.pause();

        // Holders can still change or revoke approvals during a pause.
        vm.prank(alice);
        assertTrue(token.approve(bob, 0));
        assertEq(token.allowance(alice, bob), 0);
        vm.prank(alice);
        assertTrue(token.approve(bob, 25));
        assertEq(token.allowance(alice, bob), 25);
    }

    function testHiddenPauseCheckPrecedesOtherValidation() public {
        token.pause();

        // Each call is invalid for another reason too; the pause error must win.
        vm.prank(alice);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.transfer(address(0), 1);

        vm.prank(bob);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.transfer(alice, 1);

        vm.prank(bob);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.transferFrom(alice, bob, 1);

        vm.prank(bob);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.burn(1);
    }

    function testHiddenTokenRulesWhenRunning() public {
        vm.prank(alice);
        vm.expectRevert(PausableToken.InsufficientBalance.selector);
        token.transfer(bob, 1001);

        vm.prank(alice);
        vm.expectRevert(PausableToken.ZeroAddress.selector);
        token.transfer(address(0), 1);

        vm.prank(bob);
        vm.expectRevert(PausableToken.InsufficientAllowance.selector);
        token.transferFrom(alice, bob, 1);

        vm.expectRevert(PausableToken.ZeroAddress.selector);
        token.mint(address(0), 1);

        vm.prank(alice);
        token.approve(bob, type(uint256).max);
        vm.prank(bob);
        token.transferFrom(alice, bob, 600);
        assertEq(token.allowance(alice, bob), type(uint256).max);
        assertEq(token.balanceOf(alice), 400);
        assertEq(token.balanceOf(bob), 600);
        assertEq(token.totalSupply(), 1000);
    }
}

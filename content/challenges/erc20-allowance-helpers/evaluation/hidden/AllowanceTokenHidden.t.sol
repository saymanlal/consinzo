// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AllowanceToken.sol";

contract AllowanceTokenHiddenTest is Test {
    AllowanceToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);
    uint256 internal constant MAX = type(uint256).max;

    function setUp() public {
        token = new AllowanceToken(1000);
        token.transfer(alice, 500);
    }

    function testHiddenIncreaseOverflowBoundary() public {
        vm.prank(alice);
        token.approve(bob, MAX - 10);

        vm.prank(alice);
        vm.expectRevert(AllowanceToken.AllowanceOverflow.selector);
        token.increaseAllowance(bob, 11);

        vm.prank(alice);
        vm.expectRevert(AllowanceToken.AllowanceOverflow.selector);
        token.increaseAllowance(bob, MAX);
        assertEq(token.allowance(alice, bob), MAX - 10);

        vm.prank(alice);
        assertTrue(token.increaseAllowance(bob, 10));
        assertEq(token.allowance(alice, bob), MAX);

        vm.prank(alice);
        assertTrue(token.increaseAllowance(bob, 0));
        vm.prank(alice);
        vm.expectRevert(AllowanceToken.AllowanceOverflow.selector);
        token.increaseAllowance(bob, 1);
    }

    function testHiddenDecreaseToExactlyZeroAndFromZero() public {
        vm.prank(alice);
        token.approve(bob, 40);
        vm.prank(alice);
        assertTrue(token.decreaseAllowance(bob, 40));
        assertEq(token.allowance(alice, bob), 0);

        vm.prank(alice);
        vm.expectRevert(AllowanceToken.AllowanceUnderflow.selector);
        token.decreaseAllowance(bob, 1);

        vm.prank(alice);
        assertTrue(token.decreaseAllowance(bob, 0));
        assertEq(token.allowance(alice, bob), 0);
    }

    function testHiddenInfiniteAllowanceNotDecremented() public {
        vm.prank(alice);
        token.approve(bob, MAX);

        vm.prank(bob);
        token.transferFrom(alice, carol, 200);
        vm.prank(bob);
        token.transferFrom(alice, carol, 300);

        assertEq(token.allowance(alice, bob), MAX);
        assertEq(token.balanceOf(carol), 500);
        assertEq(token.balanceOf(alice), 0);

        // Infinite allowance does not create balance.
        vm.prank(bob);
        vm.expectRevert(AllowanceToken.InsufficientBalance.selector);
        token.transferFrom(alice, carol, 1);
    }

    function testHiddenAlmostInfiniteIsFinite() public {
        vm.prank(alice);
        token.approve(bob, MAX);
        vm.prank(alice);
        token.decreaseAllowance(bob, 1);
        assertEq(token.allowance(alice, bob), MAX - 1);

        vm.prank(bob);
        token.transferFrom(alice, carol, 100);
        assertEq(token.allowance(alice, bob), MAX - 101);
    }

    function testHiddenTransferFromExactAllowanceThenRevert() public {
        vm.prank(alice);
        token.approve(bob, 75);

        vm.prank(bob);
        vm.expectRevert(AllowanceToken.InsufficientAllowance.selector);
        token.transferFrom(alice, carol, 76);

        vm.prank(bob);
        token.transferFrom(alice, carol, 75);
        assertEq(token.allowance(alice, bob), 0);

        vm.prank(bob);
        vm.expectRevert(AllowanceToken.InsufficientAllowance.selector);
        token.transferFrom(alice, carol, 1);
        assertEq(token.balanceOf(carol), 75);
    }

    function testHiddenAllowanceCheckedBeforeBalance() public {
        // carol has no balance and bob has no allowance from her.
        vm.prank(bob);
        vm.expectRevert(AllowanceToken.InsufficientAllowance.selector);
        token.transferFrom(carol, bob, 5);

        vm.prank(carol);
        token.approve(bob, 5);
        vm.prank(bob);
        vm.expectRevert(AllowanceToken.InsufficientBalance.selector);
        token.transferFrom(carol, bob, 5);
        assertEq(token.allowance(carol, bob), 5);
    }

    function testHiddenOwnerNeedsAllowanceForOwnTransferFrom() public {
        vm.prank(alice);
        vm.expectRevert(AllowanceToken.InsufficientAllowance.selector);
        token.transferFrom(alice, bob, 1);

        vm.prank(alice);
        token.increaseAllowance(alice, 10);
        vm.prank(alice);
        token.transferFrom(alice, bob, 10);
        assertEq(token.balanceOf(bob), 10);
        assertEq(token.allowance(alice, alice), 0);
    }

    function testHiddenAllowancesAreIsolatedPerOwnerAndSpender() public {
        vm.prank(alice);
        token.increaseAllowance(bob, 60);
        vm.prank(alice);
        token.increaseAllowance(carol, 5);

        assertEq(token.allowance(alice, bob), 60);
        assertEq(token.allowance(alice, carol), 5);
        assertEq(token.allowance(bob, alice), 0);

        vm.prank(carol);
        vm.expectRevert(AllowanceToken.InsufficientAllowance.selector);
        token.transferFrom(alice, carol, 6);

        // bob's allowance from alice does not apply to the deployer's tokens.
        vm.prank(bob);
        vm.expectRevert(AllowanceToken.InsufficientAllowance.selector);
        token.transferFrom(address(this), bob, 1);

        // Only the owner of the allowance can shrink it.
        vm.prank(bob);
        vm.expectRevert(AllowanceToken.AllowanceUnderflow.selector);
        token.decreaseAllowance(bob, 1);
        assertEq(token.allowance(alice, bob), 60);
    }

    function testHiddenZeroAddressChecks() public {
        vm.prank(alice);
        vm.expectRevert(AllowanceToken.ZeroAddress.selector);
        token.approve(address(0), 1);
        vm.prank(alice);
        vm.expectRevert(AllowanceToken.ZeroAddress.selector);
        token.increaseAllowance(address(0), 1);
        vm.prank(alice);
        vm.expectRevert(AllowanceToken.ZeroAddress.selector);
        token.decreaseAllowance(address(0), 0);

        vm.prank(alice);
        token.approve(bob, 10);
        vm.prank(bob);
        vm.expectRevert(AllowanceToken.ZeroAddress.selector);
        token.transferFrom(alice, address(0), 1);
        assertEq(token.allowance(alice, bob), 10);
    }
}

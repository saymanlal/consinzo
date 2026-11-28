// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BurnableToken.sol";

contract BurnableTokenHiddenTest is Test {
    BurnableToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        token = new BurnableToken(1000);
        token.transfer(alice, 400);
    }

    function testHiddenBurnBoundary() public {
        vm.prank(alice);
        vm.expectRevert(BurnableToken.InsufficientBalance.selector);
        token.burn(401);

        vm.prank(alice);
        token.burn(400);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 600);

        vm.prank(alice);
        token.burn(0);
        assertEq(token.totalSupply(), 600);
    }

    function testHiddenBurnFromExactAllowanceThenExhausted() public {
        vm.prank(alice);
        token.approve(bob, 50);

        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(alice, 51);

        vm.prank(bob);
        token.burnFrom(alice, 50);
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.balanceOf(alice), 350);

        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(alice, 1);
    }

    function testHiddenAllowanceCheckedBeforeBalance() public {
        // carol has no tokens and bob has no allowance: allowance error wins.
        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(carol, 5);

        // With allowance but no balance the balance error is reported and nothing changes.
        vm.prank(carol);
        token.approve(bob, 5);
        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientBalance.selector);
        token.burnFrom(carol, 5);
        assertEq(token.allowance(carol, bob), 5);
        assertEq(token.totalSupply(), 1000);
    }

    function testHiddenInfiniteAllowanceNotDecremented() public {
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.burnFrom(alice, 100);
        vm.prank(bob);
        token.burnFrom(alice, 300);

        assertEq(token.allowance(alice, bob), type(uint256).max);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 600);

        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientBalance.selector);
        token.burnFrom(alice, 1);
    }

    function testHiddenSelfBurnFromNeedsAllowance() public {
        vm.prank(alice);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(alice, 10);

        vm.prank(alice);
        token.approve(alice, 10);
        vm.prank(alice);
        token.burnFrom(alice, 10);
        assertEq(token.balanceOf(alice), 390);
        assertEq(token.allowance(alice, alice), 0);
    }

    function testHiddenAllowanceIsPerSpender() public {
        vm.prank(alice);
        token.approve(bob, 100);

        vm.prank(carol);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(alice, 1);

        // bob's allowance from alice does not let him burn the deployer's tokens.
        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(address(this), 1);
    }

    function testHiddenBurnedTokensAreNotCreditedAnywhere() public {
        vm.prank(alice);
        token.approve(bob, 200);
        vm.prank(bob);
        token.burnFrom(alice, 200);
        token.burn(100);

        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(alice), 200);
        assertEq(token.balanceOf(address(this)), 500);
        assertEq(token.totalSupply(), 700);
        assertEq(token.balanceOf(alice) + token.balanceOf(address(this)), token.totalSupply());
    }

    function testHiddenApproveAndTransferZeroAddress() public {
        vm.expectRevert(BurnableToken.ZeroAddress.selector);
        token.approve(address(0), 1);
        vm.expectRevert(BurnableToken.ZeroAddress.selector);
        token.transfer(address(0), 1);

        vm.prank(alice);
        token.approve(bob, 70);
        vm.prank(alice);
        token.approve(bob, 20);
        assertEq(token.allowance(alice, bob), 20);
    }
}

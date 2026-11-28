// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AllowanceToken.sol";

contract AllowanceTokenTest is Test {
    AllowanceToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        token = new AllowanceToken(1000 ether);
        token.transfer(alice, 500 ether);
    }

    function testIncreaseAllowance() public {
        vm.prank(alice);
        token.approve(bob, 100 ether);
        vm.prank(alice);
        assertTrue(token.increaseAllowance(bob, 50 ether));
        assertEq(token.allowance(alice, bob), 150 ether);
    }

    function testDecreaseAllowance() public {
        vm.prank(alice);
        token.approve(bob, 100 ether);
        vm.prank(alice);
        assertTrue(token.decreaseAllowance(bob, 30 ether));
        assertEq(token.allowance(alice, bob), 70 ether);
    }

    function testDecreaseBelowZeroReverts() public {
        vm.prank(alice);
        token.approve(bob, 100 ether);
        vm.prank(alice);
        vm.expectRevert(AllowanceToken.AllowanceUnderflow.selector);
        token.decreaseAllowance(bob, 100 ether + 1);
        assertEq(token.allowance(alice, bob), 100 ether);
    }

    function testTransferFromConsumesAllowance() public {
        vm.prank(alice);
        token.increaseAllowance(bob, 200 ether);
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, carol, 120 ether));
        assertEq(token.balanceOf(carol), 120 ether);
        assertEq(token.balanceOf(alice), 380 ether);
        assertEq(token.allowance(alice, bob), 80 ether);
    }
}

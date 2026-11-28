// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BurnableToken.sol";

contract BurnableTokenTest is Test {
    BurnableToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new BurnableToken(1000 ether);
        token.transfer(alice, 400 ether);
    }

    function testInitialSupply() public view {
        assertEq(token.totalSupply(), 1000 ether);
        assertEq(token.balanceOf(address(this)), 600 ether);
        assertEq(token.balanceOf(alice), 400 ether);
    }

    function testBurnReducesBalanceAndSupply() public {
        vm.prank(alice);
        token.burn(150 ether);
        assertEq(token.balanceOf(alice), 250 ether);
        assertEq(token.totalSupply(), 850 ether);
    }

    function testBurnFromConsumesAllowance() public {
        vm.prank(alice);
        assertTrue(token.approve(bob, 100 ether));

        vm.prank(bob);
        token.burnFrom(alice, 60 ether);

        assertEq(token.balanceOf(alice), 340 ether);
        assertEq(token.allowance(alice, bob), 40 ether);
        assertEq(token.totalSupply(), 940 ether);
        assertEq(token.balanceOf(bob), 0);
    }

    function testBurnFromWithoutAllowanceReverts() public {
        vm.prank(bob);
        vm.expectRevert(BurnableToken.InsufficientAllowance.selector);
        token.burnFrom(alice, 1);
        assertEq(token.totalSupply(), 1000 ether);
    }
}

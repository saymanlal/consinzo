// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CappedToken.sol";

contract CappedTokenTest is Test {
    CappedToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new CappedToken(1000 ether);
    }

    function testInitialState() public view {
        assertEq(token.owner(), address(this));
        assertEq(token.cap(), 1000 ether);
        assertEq(token.totalSupply(), 0);
        assertEq(token.remainingMintable(), 1000 ether);
    }

    function testMintUnderCap() public {
        token.mint(alice, 400 ether);
        assertEq(token.balanceOf(alice), 400 ether);
        assertEq(token.totalSupply(), 400 ether);
        assertEq(token.remainingMintable(), 600 ether);
    }

    function testMintOverCapReverts() public {
        token.mint(alice, 400 ether);
        vm.expectRevert(CappedToken.CapExceeded.selector);
        token.mint(bob, 601 ether);
        assertEq(token.totalSupply(), 400 ether);
        assertEq(token.balanceOf(bob), 0);
    }

    function testTransfer() public {
        token.mint(alice, 100 ether);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 30 ether));
        assertEq(token.balanceOf(alice), 70 ether);
        assertEq(token.balanceOf(bob), 30 ether);
    }
}

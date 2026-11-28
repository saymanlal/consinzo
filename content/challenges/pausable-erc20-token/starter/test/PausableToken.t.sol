// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PausableToken.sol";

contract PausableTokenTest is Test {
    PausableToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new PausableToken();
        token.mint(alice, 1000 ether);
    }

    function testTransfersWorkWhenNotPaused() public {
        assertFalse(token.paused());
        vm.prank(alice);
        assertTrue(token.transfer(bob, 100 ether));
        assertEq(token.balanceOf(bob), 100 ether);

        vm.prank(alice);
        token.approve(bob, 50 ether);
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 50 ether));
        assertEq(token.balanceOf(bob), 150 ether);
        assertEq(token.allowance(alice, bob), 0);
    }

    function testPauseBlocksTransfer() public {
        token.pause();
        assertTrue(token.paused());

        vm.prank(alice);
        vm.expectRevert(PausableToken.EnforcedPause.selector);
        token.transfer(bob, 1 ether);
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function testUnpauseRestoresTransfer() public {
        token.pause();
        token.unpause();
        assertFalse(token.paused());

        vm.prank(alice);
        assertTrue(token.transfer(bob, 1 ether));
        assertEq(token.balanceOf(bob), 1 ether);
    }

    function testOnlyOwnerCanPause() public {
        vm.prank(alice);
        vm.expectRevert(PausableToken.NotOwner.selector);
        token.pause();
        assertFalse(token.paused());
    }
}

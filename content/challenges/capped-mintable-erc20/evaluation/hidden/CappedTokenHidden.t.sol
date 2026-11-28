// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CappedToken.sol";

contract CappedTokenHiddenTest is Test {
    CappedToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new CappedToken(1000);
    }

    function testHiddenZeroCapConstructorReverts() public {
        vm.expectRevert(CappedToken.ZeroCap.selector);
        new CappedToken(0);
    }

    function testHiddenMintExactlyToCap() public {
        token.mint(alice, 999);
        token.mint(bob, 1);
        assertEq(token.totalSupply(), 1000);
        assertEq(token.remainingMintable(), 0);

        vm.expectRevert(CappedToken.CapExceeded.selector);
        token.mint(bob, 1);

        // A zero mint at the cap is still within the cap.
        token.mint(bob, 0);
        assertEq(token.totalSupply(), 1000);
    }

    function testHiddenOverflowSizedMintRevertsWithCapExceeded() public {
        token.mint(alice, 1);

        vm.expectRevert(CappedToken.CapExceeded.selector);
        token.mint(alice, type(uint256).max);

        vm.expectRevert(CappedToken.CapExceeded.selector);
        token.mint(alice, type(uint256).max - 999);

        assertEq(token.totalSupply(), 1);
        assertEq(token.balanceOf(alice), 1);
    }

    function testHiddenOnlyOwnerMints() public {
        vm.prank(alice);
        vm.expectRevert(CappedToken.NotOwner.selector);
        token.mint(alice, 1);

        // The owner check comes first, even when other arguments are invalid.
        vm.prank(alice);
        vm.expectRevert(CappedToken.NotOwner.selector);
        token.mint(address(0), 5000);
    }

    function testHiddenMintToZeroAddressReverts() public {
        vm.expectRevert(CappedToken.ZeroAddress.selector);
        token.mint(address(0), 1);
        assertEq(token.totalSupply(), 0);
    }

    function testHiddenBurnFreesRoomUnderCap() public {
        token.mint(alice, 1000);
        vm.prank(alice);
        token.burn(250);
        assertEq(token.totalSupply(), 750);
        assertEq(token.remainingMintable(), 250);

        vm.expectRevert(CappedToken.CapExceeded.selector);
        token.mint(bob, 251);

        token.mint(bob, 250);
        assertEq(token.totalSupply(), 1000);
        assertEq(token.balanceOf(bob), 250);
        assertEq(token.balanceOf(alice), 750);
    }

    function testHiddenBurnAndTransferRevertPaths() public {
        token.mint(alice, 10);

        vm.prank(alice);
        vm.expectRevert(CappedToken.InsufficientBalance.selector);
        token.burn(11);

        vm.prank(alice);
        vm.expectRevert(CappedToken.InsufficientBalance.selector);
        token.transfer(bob, 11);

        vm.prank(alice);
        vm.expectRevert(CappedToken.ZeroAddress.selector);
        token.transfer(address(0), 1);

        assertEq(token.balanceOf(alice), 10);
        assertEq(token.totalSupply(), 10);
    }

    function testHiddenTransfersDoNotAffectCapRoom() public {
        token.mint(alice, 600);
        vm.prank(alice);
        token.transfer(bob, 600);
        assertEq(token.remainingMintable(), 400);
        token.mint(alice, 400);
        vm.expectRevert(CappedToken.CapExceeded.selector);
        token.mint(alice, 1);
    }
}

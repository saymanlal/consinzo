// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MinimalNFT.sol";

contract MinimalNFTTest is Test {
    MinimalNFT public nft;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        nft = new MinimalNFT();
        nft.mint(alice, 1);
    }

    function testMintAssignsOwnership() public view {
        assertEq(nft.minter(), address(this));
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.getApproved(1), address(0));
    }

    function testOwnerTransfers() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function testApprovedAddressTransfers() public {
        vm.prank(alice);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);

        vm.prank(bob);
        nft.transferFrom(alice, carol, 1);
        assertEq(nft.ownerOf(1), carol);
        assertEq(nft.getApproved(1), address(0));
    }

    function testStrangerCannotTransfer() public {
        vm.prank(bob);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), alice);
    }
}

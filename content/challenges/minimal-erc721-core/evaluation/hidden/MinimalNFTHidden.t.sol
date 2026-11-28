// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MinimalNFT.sol";

contract MinimalNFTHiddenTest is Test {
    MinimalNFT public nft;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        nft = new MinimalNFT();
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        nft.mint(bob, 3);
    }

    function testHiddenMintRevertPaths() public {
        vm.prank(alice);
        vm.expectRevert(MinimalNFT.NotMinter.selector);
        nft.mint(alice, 10);

        vm.expectRevert(MinimalNFT.ZeroAddress.selector);
        nft.mint(address(0), 10);

        vm.expectRevert(MinimalNFT.AlreadyMinted.selector);
        nft.mint(carol, 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(carol), 0);
    }

    function testHiddenNonexistentTokenQueriesRevert() public {
        vm.expectRevert(MinimalNFT.NonexistentToken.selector);
        nft.ownerOf(99);
        vm.expectRevert(MinimalNFT.NonexistentToken.selector);
        nft.getApproved(99);
        vm.expectRevert(MinimalNFT.NonexistentToken.selector);
        nft.approve(bob, 99);
        vm.expectRevert(MinimalNFT.NonexistentToken.selector);
        nft.transferFrom(address(0), bob, 99);
        vm.expectRevert(MinimalNFT.ZeroAddress.selector);
        nft.balanceOf(address(0));
    }

    function testHiddenTokenIdZeroIsValid() public {
        vm.expectRevert(MinimalNFT.NonexistentToken.selector);
        nft.ownerOf(0);

        nft.mint(carol, 0);
        assertEq(nft.ownerOf(0), carol);
        vm.prank(carol);
        nft.transferFrom(carol, alice, 0);
        assertEq(nft.ownerOf(0), alice);
        assertEq(nft.balanceOf(alice), 3);
        assertEq(nft.balanceOf(carol), 0);
    }

    function testHiddenOnlyOwnerCanApprove() public {
        vm.prank(bob);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.approve(bob, 1);

        // An approved address may transfer but may not re-approve.
        vm.prank(alice);
        nft.approve(bob, 1);
        vm.prank(bob);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.approve(carol, 1);
        assertEq(nft.getApproved(1), bob);

        // The owner can clear the approval.
        vm.prank(alice);
        nft.approve(address(0), 1);
        assertEq(nft.getApproved(1), address(0));
        vm.prank(bob);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.transferFrom(alice, bob, 1);
    }

    function testHiddenApprovalIsPerToken() public {
        vm.prank(alice);
        nft.approve(carol, 1);

        vm.prank(carol);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.transferFrom(alice, carol, 2);

        vm.prank(carol);
        nft.transferFrom(alice, carol, 1);
        assertEq(nft.ownerOf(1), carol);
        assertEq(nft.ownerOf(2), alice);
    }

    function testHiddenWrongFromAndZeroRecipient() public {
        vm.prank(alice);
        vm.expectRevert(MinimalNFT.WrongOwner.selector);
        nft.transferFrom(bob, carol, 1);

        // Caller owns token 3 but names it with someone else's `from`.
        vm.prank(bob);
        vm.expectRevert(MinimalNFT.WrongOwner.selector);
        nft.transferFrom(alice, carol, 3);

        vm.prank(alice);
        vm.expectRevert(MinimalNFT.ZeroAddress.selector);
        nft.transferFrom(alice, address(0), 1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 2);
    }

    function testHiddenStaleApprovalDoesNotSurviveRoundTrip() public {
        vm.prank(alice);
        nft.approve(carol, 1);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.getApproved(1), address(0));

        vm.prank(bob);
        nft.transferFrom(bob, alice, 1);

        // carol's old approval from alice must be gone even though alice owns it again.
        vm.prank(carol);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.transferFrom(alice, carol, 1);
        assertEq(nft.ownerOf(1), alice);
    }

    function testHiddenPreviousOwnerLosesControl() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);

        vm.prank(alice);
        vm.expectRevert(MinimalNFT.WrongOwner.selector);
        nft.transferFrom(alice, carol, 1);

        vm.prank(alice);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.transferFrom(bob, alice, 1);

        vm.prank(alice);
        vm.expectRevert(MinimalNFT.NotAuthorized.selector);
        nft.approve(alice, 1);
    }

    function testHiddenBalancesAcrossSeveralTransfers() public {
        vm.prank(alice);
        nft.transferFrom(alice, bob, 1);
        vm.prank(alice);
        nft.transferFrom(alice, carol, 2);
        vm.prank(bob);
        nft.transferFrom(bob, carol, 3);
        vm.prank(bob);
        nft.transferFrom(bob, bob, 1);

        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.balanceOf(carol), 2);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.ownerOf(2), carol);
        assertEq(nft.ownerOf(3), carol);
    }
}

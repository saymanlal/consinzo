// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConsinzoNFT.sol";

contract ConsinzoNFTTest is Test {
    ConsinzoNFT public nft;
    address public treasury = address(0x777);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        nft = new ConsinzoNFT("Consinzo Pass", "CSZP", 2, treasury, 500);
    }

    function testMintAndTransfer() public {
        uint256 id = nft.mint(alice);
        assertEq(id, 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);

        vm.prank(alice);
        nft.approve(bob, 1);
        vm.prank(bob);
        nft.transferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.getApproved(1), address(0));
    }

    function testRoyaltyCalculation() public {
        nft.mint(alice);
        (address receiver, uint256 amt) = nft.royaltyInfo(1, 10 ether);
        assertEq(receiver, treasury);
        assertEq(amt, 0.5 ether);
    }
}

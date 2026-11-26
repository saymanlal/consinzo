// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConsinzoNFT.sol";

contract ConsinzoNFTHiddenTest is Test {
    ConsinzoNFT public nft;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        nft = new ConsinzoNFT("Consinzo Pass", "CSZP", 2, address(0x777), 500);
    }

    function testHiddenMaxSupplyEnforced() public {
        nft.mint(alice);
        nft.mint(alice);
        vm.expectRevert();
        nft.mint(alice);
    }

    function testHiddenUnauthorizedTransferReverts() public {
        nft.mint(alice);
        vm.prank(bob);
        vm.expectRevert();
        nft.transferFrom(alice, bob, 1);
    }
}

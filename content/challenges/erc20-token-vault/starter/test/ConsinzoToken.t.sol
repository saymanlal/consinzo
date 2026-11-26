// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConsinzoToken.sol";

contract ConsinzoTokenTest is Test {
    ConsinzoToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new ConsinzoToken("Consinzo Token", "CSZ");
    }

    function testMetadata() public view {
        assertEq(token.name(), "Consinzo Token");
        assertEq(token.symbol(), "CSZ");
        assertEq(uint256(token.decimals()), 18);
    }

    function testMintAndTransfer() public {
        token.mint(alice, 1000 ether);
        assertEq(token.totalSupply(), 1000 ether);
        assertEq(token.balanceOf(alice), 1000 ether);

        vm.prank(alice);
        assertTrue(token.transfer(bob, 250 ether));
        assertEq(token.balanceOf(alice), 750 ether);
        assertEq(token.balanceOf(bob), 250 ether);
    }

    function testApproveAndTransferFrom() public {
        token.mint(alice, 500 ether);
        vm.prank(alice);
        assertTrue(token.approve(bob, 200 ether));
        assertEq(token.allowance(alice, bob), 200 ether);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, 150 ether));
        assertEq(token.balanceOf(bob), 150 ether);
        assertEq(token.allowance(alice, bob), 50 ether);
    }

    function testBurnReducesSupply() public {
        token.mint(alice, 300 ether);
        vm.prank(alice);
        token.burn(100 ether);
        assertEq(token.balanceOf(alice), 200 ether);
        assertEq(token.totalSupply(), 200 ether);
    }
}

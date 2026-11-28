// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RewardToken.sol";

contract RewardTokenTest is Test {
    RewardToken public token;
    address public alice = address(0xA11CE);
    address public mallory = address(0xBAD);

    function setUp() public {
        token = new RewardToken();
    }

    function testOwnerCanMint() public {
        token.mint(alice, 500);
        assertEq(token.balanceOf(alice), 500);
        assertEq(token.totalSupply(), 500);
    }

    function testStrangerCannotMint() public {
        vm.prank(mallory);
        vm.expectRevert(RewardToken.NotOwner.selector);
        token.mint(mallory, 1_000_000);
        assertEq(token.balanceOf(mallory), 0);
        assertEq(token.totalSupply(), 0);
    }

    function testHoldersCanTransfer() public {
        token.mint(alice, 500);
        vm.prank(alice);
        token.transfer(mallory, 200);
        assertEq(token.balanceOf(alice), 300);
        assertEq(token.balanceOf(mallory), 200);
        assertEq(token.totalSupply(), 500);
    }
}

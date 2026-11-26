// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ConsinzoToken.sol";

contract ConsinzoTokenHiddenTest is Test {
    ConsinzoToken public token;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new ConsinzoToken("Consinzo Token", "CSZ");
    }

    function testHiddenNonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100 ether);
    }

    function testHiddenZeroAddressChecks() public {
        token.mint(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(address(0), 10 ether);

        vm.prank(alice);
        vm.expectRevert();
        token.approve(address(0), 10 ether);
    }

    function testHiddenInfiniteAllowanceNotDecremented() public {
        token.mint(alice, 500 ether);
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, bob, 125 ether);
        assertEq(token.allowance(alice, bob), type(uint256).max);
        assertEq(token.balanceOf(bob), 125 ether);
    }

    function testHiddenInsufficientBalanceReverts() public {
        token.mint(alice, 50 ether);
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 51 ether);

        vm.prank(alice);
        vm.expectRevert();
        token.burn(51 ether);
    }
}

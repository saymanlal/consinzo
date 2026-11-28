// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TipJar.sol";

contract TipJarTest is Test {
    TipJar public jar;
    address public jarOwner = address(0x0A11);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        vm.prank(jarOwner);
        jar = new TipJar();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testOwnerIsDeployer() public view {
        assertEq(jar.owner(), jarOwner);
        assertEq(jar.totalTips(), 0);
    }

    function testTipFunction() public {
        vm.prank(alice);
        jar.tip{value: 1 ether}();
        assertEq(jar.tipsOf(alice), 1 ether);
        assertEq(jar.totalTips(), 1 ether);
        assertEq(jar.tipperCount(), 1);
        assertEq(address(jar).balance, 1 ether);
    }

    function testPlainTransferIsATip() public {
        vm.prank(bob);
        (bool ok,) = address(jar).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(jar.tipsOf(bob), 2 ether);
        assertEq(jar.totalTips(), 2 ether);
    }

    function testOwnerWithdraws() public {
        vm.prank(alice);
        jar.tip{value: 3 ether}();

        vm.prank(jarOwner);
        jar.withdraw();
        assertEq(jarOwner.balance, 3 ether);
        assertEq(address(jar).balance, 0);
    }

    function testStrangerCannotWithdraw() public {
        vm.prank(alice);
        jar.tip{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(TipJar.NotOwner.selector);
        jar.withdraw();
    }
}

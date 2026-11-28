// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TipJar.sol";

contract TipJarTest is Test {
    TipJar public jar;
    address public owner = address(0x0A11CE);
    address public fan = address(0xFA17);
    address public thief = address(0xBAD);

    function setUp() public {
        jar = new TipJar(owner);
        vm.deal(fan, 10 ether);
        vm.prank(fan);
        jar.tip{value: 3 ether}();
    }

    function testTipIsRecorded() public {
        assertEq(jar.totalTips(), 3 ether);
        assertEq(jar.tipsFrom(fan), 3 ether);
        assertEq(address(jar).balance, 3 ether);
    }

    function testOwnerWithdrawsEverything() public {
        vm.prank(owner);
        jar.withdrawAll();
        assertEq(owner.balance, 3 ether);
        assertEq(address(jar).balance, 0);
    }

    function testStrangerCannotSweepTheJar() public {
        vm.prank(thief);
        vm.expectRevert(TipJar.NotOwner.selector);
        jar.withdrawAll();
        assertEq(thief.balance, 0);
        assertEq(address(jar).balance, 3 ether);
    }
}

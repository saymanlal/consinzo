// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TipJar.sol";

contract Sweeper {
    function sweep(TipJar jar) external returns (bool ok) {
        (ok, ) = address(jar).call(abi.encodeCall(TipJar.withdrawAll, ()));
    }

    receive() external payable {}
}

contract TipJarHiddenTest is Test {
    TipJar public jar;
    address public owner = address(0x0A11CE);
    address public fan = address(0xFA17);
    address public thief = address(0xBAD);

    function setUp() public {
        jar = new TipJar(owner);
        vm.deal(fan, 10 ether);
    }

    function testHiddenContractCannotSweep() public {
        vm.prank(fan);
        jar.tip{value: 2 ether}();
        Sweeper sweeper = new Sweeper();
        assertFalse(sweeper.sweep(jar));
        assertEq(address(sweeper).balance, 0);
        assertEq(address(jar).balance, 2 ether);
    }

    function testHiddenTipperCannotTakeTipsBack() public {
        vm.prank(fan);
        jar.tip{value: 2 ether}();
        vm.prank(fan);
        vm.expectRevert(TipJar.NotOwner.selector);
        jar.withdrawAll();
        assertEq(fan.balance, 8 ether);
    }

    function testHiddenStrangerGetsNotOwnerOnEmptyJar() public {
        vm.prank(thief);
        vm.expectRevert(TipJar.NotOwner.selector);
        jar.withdrawAll();
    }

    function testHiddenOwnerEmptyJarReverts() public {
        vm.prank(owner);
        vm.expectRevert(TipJar.NothingToWithdraw.selector);
        jar.withdrawAll();
    }

    function testHiddenPlainTransfersAreCollected() public {
        vm.prank(fan);
        (bool ok, ) = address(jar).call{value: 1 ether}("");
        assertTrue(ok);
        vm.prank(fan);
        jar.tip{value: 4 ether}();
        assertEq(jar.totalTips(), 5 ether);
        assertEq(jar.tipsFrom(fan), 5 ether);

        vm.prank(owner);
        jar.withdrawAll();
        assertEq(owner.balance, 5 ether);
        assertEq(address(jar).balance, 0);
    }

    function testHiddenOwnerCanWithdrawRepeatedlyAsTipsArrive() public {
        vm.prank(fan);
        jar.tip{value: 1 ether}();
        vm.prank(owner);
        jar.withdrawAll();
        vm.prank(fan);
        jar.tip{value: 2 ether}();
        vm.prank(owner);
        jar.withdrawAll();
        assertEq(owner.balance, 3 ether);
        // totalTips is a running total and is not reset by withdrawals.
        assertEq(jar.totalTips(), 3 ether);
    }

    function testHiddenZeroTipRejected() public {
        vm.prank(fan);
        vm.expectRevert(TipJar.ZeroTip.selector);
        jar.tip{value: 0}();
    }
}

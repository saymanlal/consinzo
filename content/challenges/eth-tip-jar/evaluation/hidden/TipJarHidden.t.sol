// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TipJar.sol";

contract TipJarHiddenTest is Test {
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

    function testHiddenZeroTipRejected() public {
        vm.prank(alice);
        vm.expectRevert(TipJar.ZeroTip.selector);
        jar.tip{value: 0}();

        vm.prank(alice);
        (bool ok,) = address(jar).call{value: 0}("");
        assertFalse(ok);

        assertEq(jar.tipperCount(), 0);
        assertEq(jar.totalTips(), 0);
    }

    function testHiddenTotalsAccumulatePerTipper() public {
        vm.startPrank(alice);
        jar.tip{value: 1 ether}();
        jar.tip{value: 0.5 ether}();
        (bool ok,) = address(jar).call{value: 0.25 ether}("");
        vm.stopPrank();
        assertTrue(ok);

        vm.prank(bob);
        jar.tip{value: 4 ether}();

        assertEq(jar.tipsOf(alice), 1.75 ether);
        assertEq(jar.tipsOf(bob), 4 ether);
        assertEq(jar.totalTips(), 5.75 ether);
        assertEq(jar.tipperCount(), 2);
        assertEq(address(jar).balance, 5.75 ether);
    }

    function testHiddenWithdrawRevertCarriesCaller() public {
        vm.prank(alice);
        jar.tip{value: 1 ether}();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(TipJar.NotOwner.selector, bob));
        jar.withdraw();
        assertEq(address(jar).balance, 1 ether);
    }

    function testHiddenEmptyJarCannotBeWithdrawn() public {
        vm.prank(jarOwner);
        vm.expectRevert(TipJar.NothingToWithdraw.selector);
        jar.withdraw();

        vm.prank(alice);
        jar.tip{value: 1 ether}();
        vm.prank(jarOwner);
        jar.withdraw();

        vm.prank(jarOwner);
        vm.expectRevert(TipJar.NothingToWithdraw.selector);
        jar.withdraw();
    }

    function testHiddenStatisticsSurviveWithdrawal() public {
        vm.prank(alice);
        jar.tip{value: 2 ether}();
        vm.prank(jarOwner);
        jar.withdraw();

        assertEq(jar.tipsOf(alice), 2 ether);
        assertEq(jar.totalTips(), 2 ether);
        assertEq(jar.tipperCount(), 1);

        // Tipping continues after a withdrawal and alice is not counted twice.
        vm.prank(alice);
        jar.tip{value: 1 ether}();
        vm.prank(bob);
        jar.tip{value: 1 ether}();
        assertEq(jar.tipsOf(alice), 3 ether);
        assertEq(jar.totalTips(), 4 ether);
        assertEq(jar.tipperCount(), 2);

        vm.prank(jarOwner);
        jar.withdraw();
        assertEq(jarOwner.balance, 4 ether);
        assertEq(address(jar).balance, 0);
    }

    function testHiddenWithdrawSendsWholeBalance() public {
        vm.prank(alice);
        jar.tip{value: 1 wei}();
        vm.prank(bob);
        jar.tip{value: 7 ether}();
        uint256 before = jarOwner.balance;
        vm.prank(jarOwner);
        jar.withdraw();
        assertEq(jarOwner.balance - before, 7 ether + 1);
    }

    function testHiddenFailedTransferReverts() public {
        // This test contract has no receive function, so it cannot accept the withdrawal.
        TipJar mine = new TipJar();
        assertEq(mine.owner(), address(this));
        vm.prank(alice);
        mine.tip{value: 1 ether}();

        vm.expectRevert(TipJar.TransferFailed.selector);
        mine.withdraw();
        assertEq(address(mine).balance, 1 ether);
    }
}

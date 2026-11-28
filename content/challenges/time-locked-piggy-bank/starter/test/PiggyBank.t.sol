// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PiggyBank.sol";

contract PiggyBankTest is Test {
    PiggyBank public bank;
    address public saver = address(0x5A7E);
    address public alice = address(0xA11CE);
    uint256 public unlockAt;

    function setUp() public {
        unlockAt = block.timestamp + 30 days;
        vm.prank(saver);
        bank = new PiggyBank(unlockAt);
        vm.deal(saver, 10 ether);
        vm.deal(alice, 10 ether);
    }

    function testInitialState() public view {
        assertEq(bank.owner(), saver);
        assertEq(bank.unlockTime(), unlockAt);
        assertFalse(bank.isUnlocked());
        assertEq(bank.secondsUntilUnlock(), 30 days);
    }

    function testAnyoneCanDeposit() public {
        vm.prank(saver);
        bank.deposit{value: 1 ether}();
        vm.prank(alice);
        bank.deposit{value: 2 ether}();
        assertEq(bank.totalDeposited(), 3 ether);
        assertEq(address(bank).balance, 3 ether);
    }

    function testCannotWithdrawWhileLocked() public {
        vm.prank(saver);
        bank.deposit{value: 1 ether}();

        vm.prank(saver);
        vm.expectRevert(abi.encodeWithSelector(PiggyBank.StillLocked.selector, unlockAt));
        bank.withdraw();
    }

    function testWithdrawAfterUnlock() public {
        vm.prank(saver);
        bank.deposit{value: 4 ether}();

        vm.warp(unlockAt + 1);
        assertTrue(bank.isUnlocked());

        vm.prank(saver);
        bank.withdraw();
        assertEq(address(bank).balance, 0);
        assertEq(saver.balance, 10 ether);
    }
}

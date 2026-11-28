// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PiggyBank.sol";

contract PiggyBankHiddenTest is Test {
    PiggyBank public bank;
    address public saver = address(0x5A7E);
    address public alice = address(0xA11CE);
    uint256 public unlockAt;

    function setUp() public {
        unlockAt = block.timestamp + 7 days;
        vm.prank(saver);
        bank = new PiggyBank(unlockAt);
        vm.deal(saver, 10 ether);
        vm.deal(alice, 10 ether);
    }

    function testHiddenConstructorRejectsPresentAndPast() public {
        uint256 nowTs = block.timestamp;
        try new PiggyBank(nowTs) {
            assertTrue(false, "unlock time equal to now accepted");
        } catch (bytes memory data) {
            assertEq(
                keccak256(data),
                keccak256(abi.encodeWithSelector(PiggyBank.UnlockTimeNotInFuture.selector, nowTs))
            );
        }
        try new PiggyBank(nowTs - 1) {
            assertTrue(false, "past unlock time accepted");
        } catch (bytes memory data) {
            assertEq(
                keccak256(data),
                keccak256(abi.encodeWithSelector(PiggyBank.UnlockTimeNotInFuture.selector, nowTs - 1))
            );
        }
        try new PiggyBank(0) {
            assertTrue(false, "zero unlock time accepted");
        } catch {}

        PiggyBank soon = new PiggyBank(nowTs + 1);
        assertEq(soon.secondsUntilUnlock(), 1);
    }

    function testHiddenUnlockBoundaryIsInclusive() public {
        vm.prank(alice);
        bank.deposit{value: 1 ether}();

        vm.warp(unlockAt - 1);
        assertFalse(bank.isUnlocked());
        assertEq(bank.secondsUntilUnlock(), 1);
        vm.prank(saver);
        vm.expectRevert(abi.encodeWithSelector(PiggyBank.StillLocked.selector, unlockAt));
        bank.withdraw();

        vm.warp(unlockAt);
        assertTrue(bank.isUnlocked());
        assertEq(bank.secondsUntilUnlock(), 0);
        vm.prank(saver);
        bank.withdraw();
        assertEq(saver.balance, 11 ether);
    }

    function testHiddenSecondsUntilUnlockNeverReverts() public {
        vm.warp(unlockAt - 3 days);
        assertEq(bank.secondsUntilUnlock(), 3 days);
        vm.warp(unlockAt + 365 days);
        assertEq(bank.secondsUntilUnlock(), 0);
        assertTrue(bank.isUnlocked());
    }

    function testHiddenPlainTransferAndZeroDeposit() public {
        vm.prank(alice);
        (bool ok,) = address(bank).call{value: 1.5 ether}("");
        assertTrue(ok);
        assertEq(bank.totalDeposited(), 1.5 ether);

        vm.prank(alice);
        vm.expectRevert(PiggyBank.ZeroDeposit.selector);
        bank.deposit{value: 0}();

        vm.prank(alice);
        (ok,) = address(bank).call{value: 0}("");
        assertFalse(ok);
        assertEq(bank.totalDeposited(), 1.5 ether);
    }

    function testHiddenOnlyOwnerWithdraws() public {
        vm.prank(alice);
        bank.deposit{value: 2 ether}();

        // Before unlock a stranger gets the caller error, not the lock error.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PiggyBank.NotOwner.selector, alice));
        bank.withdraw();

        vm.warp(unlockAt + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PiggyBank.NotOwner.selector, alice));
        bank.withdraw();
        assertEq(address(bank).balance, 2 ether);
    }

    function testHiddenLockCheckedBeforeEmptyCheck() public {
        // Empty and locked: the lock error wins.
        vm.prank(saver);
        vm.expectRevert(abi.encodeWithSelector(PiggyBank.StillLocked.selector, unlockAt));
        bank.withdraw();

        vm.warp(unlockAt);
        vm.prank(saver);
        vm.expectRevert(PiggyBank.NothingToWithdraw.selector);
        bank.withdraw();
    }

    function testHiddenDepositsAfterUnlockAndSecondWithdrawal() public {
        vm.prank(saver);
        bank.deposit{value: 3 ether}();
        vm.warp(unlockAt + 10);
        vm.prank(saver);
        bank.withdraw();
        assertEq(saver.balance, 10 ether);

        vm.prank(saver);
        vm.expectRevert(PiggyBank.NothingToWithdraw.selector);
        bank.withdraw();

        vm.prank(alice);
        bank.deposit{value: 1 ether}();
        assertEq(bank.totalDeposited(), 4 ether);

        vm.prank(saver);
        bank.withdraw();
        assertEq(saver.balance, 11 ether);
        assertEq(address(bank).balance, 0);
        assertEq(bank.totalDeposited(), 4 ether);
    }

    function testHiddenFailedTransferReverts() public {
        // The test contract cannot receive ETH, so its own bank cannot pay out.
        PiggyBank mine = new PiggyBank(block.timestamp + 1 days);
        vm.prank(alice);
        mine.deposit{value: 1 ether}();
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(PiggyBank.TransferFailed.selector);
        mine.withdraw();
        assertEq(address(mine).balance, 1 ether);
    }
}

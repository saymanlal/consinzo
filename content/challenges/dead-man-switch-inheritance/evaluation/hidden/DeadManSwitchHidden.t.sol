// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DeadManSwitch.sol";

contract DeadManSwitchHiddenTest is Test {
    DeadManSwitch public wallet;
    address public owner = address(0x0A11CE);
    address public heir = address(0xB0B);
    address public other = address(0xCA401);

    uint256 constant PERIOD = 30 days;
    uint256 start;

    function setUp() public {
        vm.deal(owner, 10 ether);
        vm.prank(owner);
        wallet = new DeadManSwitch{value: 10 ether}(heir, PERIOD);
        start = block.timestamp;
    }

    function testHiddenClaimOneSecondEarlyReverts() public {
        vm.warp(start + PERIOD - 1);
        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.OwnerStillActive.selector);
        wallet.claim();

        vm.warp(start + PERIOD);
        vm.prank(heir);
        wallet.claim();
        assertEq(wallet.owner(), heir);
    }

    function testHiddenOnlyHeirClaims() public {
        vm.warp(start + PERIOD * 2);
        vm.prank(other);
        vm.expectRevert(DeadManSwitch.NotHeir.selector);
        wallet.claim();

        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.NotHeir.selector);
        wallet.claim();
    }

    function testHiddenOwnerOnlyFunctions() public {
        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.NotOwner.selector);
        wallet.heartbeat();

        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.NotOwner.selector);
        wallet.setHeir(other);

        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.NotOwner.selector);
        wallet.withdraw(1 ether);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(wallet.lastHeartbeat(), start);
    }

    function testHiddenLateHeartbeatStillSavesOwner() public {
        // The owner was silent for longer than the period, but the heir never claimed.
        vm.warp(start + PERIOD + 5 days);
        vm.prank(owner);
        wallet.heartbeat();

        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.OwnerStillActive.selector);
        wallet.claim();
        assertEq(wallet.claimableAt(), start + PERIOD + 5 days + PERIOD);
    }

    function testHiddenSetHeirReplacesHeirAndResetsTimer() public {
        vm.warp(start + 29 days);
        vm.prank(owner);
        wallet.setHeir(other);
        assertEq(wallet.heir(), other);
        assertEq(wallet.lastHeartbeat(), start + 29 days);

        vm.warp(start + 29 days + PERIOD);
        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.NotHeir.selector);
        wallet.claim();

        vm.prank(other);
        wallet.claim();
        assertEq(wallet.owner(), other);
    }

    function testHiddenSetHeirRejectsInvalidAddresses() public {
        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.InvalidHeir.selector);
        wallet.setHeir(address(0));

        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.InvalidHeir.selector);
        wallet.setHeir(owner);
        assertEq(wallet.heir(), heir);
    }

    function testHiddenPreviousOwnerLosesAllRights() public {
        vm.warp(start + PERIOD);
        vm.prank(heir);
        wallet.claim();

        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.NotOwner.selector);
        wallet.withdraw(1 ether);
        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.NotOwner.selector);
        wallet.heartbeat();
        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.NotOwner.selector);
        wallet.setHeir(owner);
    }

    function testHiddenNoSecondClaimWithoutNewHeir() public {
        vm.warp(start + PERIOD);
        vm.prank(heir);
        wallet.claim();

        // Long silence by the new owner: nobody is heir, so nobody can claim.
        vm.warp(start + PERIOD * 10);
        vm.prank(heir);
        vm.expectRevert(DeadManSwitch.NotHeir.selector);
        wallet.claim();
        assertEq(wallet.owner(), heir);
    }

    function testHiddenInheritanceChain() public {
        vm.warp(start + PERIOD);
        vm.prank(heir);
        wallet.claim();
        vm.prank(heir);
        wallet.setHeir(other);

        uint256 t = block.timestamp;
        vm.warp(t + PERIOD - 1);
        vm.prank(other);
        vm.expectRevert(DeadManSwitch.OwnerStillActive.selector);
        wallet.claim();

        vm.warp(t + PERIOD);
        vm.prank(other);
        wallet.claim();
        assertEq(wallet.owner(), other);

        vm.prank(other);
        wallet.withdraw(10 ether);
        assertEq(other.balance, 10 ether);
    }

    function testHiddenWithdrawMoreThanBalanceReverts() public {
        vm.prank(owner);
        vm.expectRevert(DeadManSwitch.TransferFailed.selector);
        wallet.withdraw(10 ether + 1);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testHiddenReceiveAcceptsDeposits() public {
        (bool ok, ) = address(wallet).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(address(wallet).balance, 12 ether);
        // A deposit by a stranger is not a heartbeat.
        assertEq(wallet.lastHeartbeat(), start);
    }
}

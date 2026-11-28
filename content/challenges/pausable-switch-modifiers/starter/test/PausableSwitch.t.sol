// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PausableSwitch.sol";

contract PausableSwitchTest is Test {
    PausableSwitch public sw;
    address public alice = address(0xA11CE);

    function setUp() public {
        sw = new PausableSwitch();
    }

    function testStartsUnpaused() public view {
        assertFalse(sw.paused());
        assertEq(sw.owner(), address(this));
    }

    function testPingWhileRunning() public {
        vm.prank(alice);
        sw.ping();
        sw.ping();
        assertEq(sw.pingsOf(alice), 1);
        assertEq(sw.totalPings(), 2);
    }

    function testPingBlockedWhilePaused() public {
        sw.pause();
        assertTrue(sw.paused());
        vm.prank(alice);
        vm.expectRevert(PausableSwitch.EnforcedPause.selector);
        sw.ping();
    }

    function testResetOnlyWhilePaused() public {
        sw.ping();
        vm.expectRevert(PausableSwitch.ExpectedPause.selector);
        sw.emergencyReset();

        sw.pause();
        sw.emergencyReset();
        assertEq(sw.totalPings(), 0);
    }

    function testOnlyOwnerPauses() public {
        vm.prank(alice);
        vm.expectRevert(PausableSwitch.NotOwner.selector);
        sw.pause();
        assertFalse(sw.paused());
    }
}

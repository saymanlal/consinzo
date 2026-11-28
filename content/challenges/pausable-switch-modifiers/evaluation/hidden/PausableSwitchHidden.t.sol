// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PausableSwitch.sol";

contract PausableSwitchHiddenTest is Test {
    PausableSwitch public sw;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        sw = new PausableSwitch();
    }

    function testHiddenDoublePauseAndDoubleUnpause() public {
        vm.expectRevert(PausableSwitch.ExpectedPause.selector);
        sw.unpause();

        sw.pause();
        vm.expectRevert(PausableSwitch.EnforcedPause.selector);
        sw.pause();
        assertTrue(sw.paused());

        sw.unpause();
        assertFalse(sw.paused());
        vm.expectRevert(PausableSwitch.ExpectedPause.selector);
        sw.unpause();
    }

    function testHiddenPingResumesAfterUnpause() public {
        vm.prank(alice);
        sw.ping();
        sw.pause();
        sw.unpause();
        vm.prank(alice);
        sw.ping();
        assertEq(sw.pingsOf(alice), 2);
        assertEq(sw.totalPings(), 2);
    }

    function testHiddenNonOwnerAlwaysGetsNotOwner() public {
        // Running: unpause and emergencyReset would also fail the pause check,
        // but the owner check comes first.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PausableSwitch.NotOwner.selector, alice));
        sw.unpause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PausableSwitch.NotOwner.selector, alice));
        sw.emergencyReset();

        sw.pause();

        // Paused: pause would also fail the pause check.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PausableSwitch.NotOwner.selector, bob));
        sw.pause();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PausableSwitch.NotOwner.selector, bob));
        sw.unpause();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(PausableSwitch.NotOwner.selector, bob));
        sw.emergencyReset();

        assertTrue(sw.paused());
    }

    function testHiddenResetKeepsPerAccountCounts() public {
        vm.startPrank(alice);
        sw.ping();
        sw.ping();
        sw.ping();
        vm.stopPrank();
        vm.prank(bob);
        sw.ping();
        assertEq(sw.totalPings(), 4);

        sw.pause();
        sw.emergencyReset();
        assertEq(sw.totalPings(), 0);
        assertEq(sw.pingsOf(alice), 3);
        assertEq(sw.pingsOf(bob), 1);
        assertTrue(sw.paused());

        // Reset is still allowed while paused, even with nothing to clear.
        sw.emergencyReset();

        sw.unpause();
        vm.prank(bob);
        sw.ping();
        assertEq(sw.totalPings(), 1);
        assertEq(sw.pingsOf(bob), 2);
    }

    function testHiddenPauseBlocksEveryCaller() public {
        sw.pause();
        vm.expectRevert(PausableSwitch.EnforcedPause.selector);
        sw.ping();
        vm.prank(bob);
        vm.expectRevert(PausableSwitch.EnforcedPause.selector);
        sw.ping();
        assertEq(sw.totalPings(), 0);
    }

    function testHiddenOwnerIsDeployer() public {
        vm.prank(alice);
        PausableSwitch other = new PausableSwitch();
        assertEq(other.owner(), alice);

        vm.expectRevert(abi.encodeWithSelector(PausableSwitch.NotOwner.selector, address(this)));
        other.pause();

        vm.prank(alice);
        other.pause();
        assertTrue(other.paused());
    }
}

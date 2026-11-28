// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RouteRateLimiter.sol";

contract RouteRateLimiterHiddenTest is Test {
    uint256 internal constant CHAIN = 10;
    uint256 internal constant OTHER = 137;
    uint256 internal constant T0 = 1_700_000_000;

    RouteRateLimiter public limiter;
    address public bridge = address(0xB41D6E);
    address public guardian = address(0x6A4D);
    address public mallory = address(0xBAD);

    function setUp() public {
        vm.warp(T0);
        limiter = new RouteRateLimiter(bridge, guardian);
        // bucket: 1000 units, +10 per second; breaker: 2500 units per hour
        limiter.configureRoute(CHAIN, 1_000, 10, 2_500, 1 hours);
    }

    function _consume(uint256 chain, uint256 amount) internal returns (bool ok) {
        vm.prank(bridge);
        ok = limiter.consume(chain, amount);
    }

    function testHiddenConstructorAndConfigValidation() public {
        vm.expectRevert(RouteRateLimiter.InvalidConfig.selector);
        new RouteRateLimiter(address(0), guardian);
        RouteRateLimiter l = new RouteRateLimiter(bridge, address(0)); // no guardian is fine
        assertEq(l.guardian(), address(0));

        vm.expectRevert(RouteRateLimiter.InvalidConfig.selector);
        l.configureRoute(0, 1, 1, 1, 1);
        vm.expectRevert(RouteRateLimiter.InvalidConfig.selector);
        l.configureRoute(1, 0, 1, 1, 1);
        vm.expectRevert(RouteRateLimiter.InvalidConfig.selector);
        l.configureRoute(1, 1, 1, 0, 1);
        vm.expectRevert(RouteRateLimiter.InvalidConfig.selector);
        l.configureRoute(1, 1, 1, 1, 0);
        l.configureRoute(1, 1, 0, 1, 1); // zero refill is allowed
        vm.prank(mallory);
        vm.expectRevert(RouteRateLimiter.NotOwner.selector);
        l.configureRoute(0, 0, 0, 0, 0);
    }

    function testHiddenConsumeRevertOrder() public {
        vm.prank(mallory);
        vm.expectRevert(RouteRateLimiter.NotBridge.selector);
        limiter.consume(OTHER, 0);
        vm.startPrank(bridge);
        vm.expectRevert(RouteRateLimiter.RouteNotConfigured.selector);
        limiter.consume(OTHER, 0);
        vm.expectRevert(RouteRateLimiter.ZeroAmount.selector);
        limiter.consume(CHAIN, 0);
        vm.expectRevert(RouteRateLimiter.RouteNotConfigured.selector);
        limiter.replenish(OTHER, 1);
        vm.stopPrank();
        vm.prank(mallory);
        vm.expectRevert(RouteRateLimiter.NotBridge.selector);
        limiter.replenish(CHAIN, 1);
    }

    function testHiddenThresholdBoundaryIsInclusive() public {
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 100);
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 150);
        assertTrue(_consume(CHAIN, 500)); // exactly 2500: allowed
        assertFalse(limiter.isPaused(CHAIN));
        assertEq(limiter.windowOutflow(CHAIN), 2_500);
        vm.warp(T0 + 151);
        assertFalse(_consume(CHAIN, 1)); // 2501: trips
        assertTrue(limiter.isPaused(CHAIN));
    }

    function testHiddenTripCannotBeDodgedWithSmallerRetry() public {
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 100);
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 200);
        assertFalse(_consume(CHAIN, 600)); // trips
        // 500 would have fitted under the threshold, but the route is now paused
        assertFalse(_consume(CHAIN, 500));
        assertFalse(_consume(CHAIN, 1));
        vm.warp(T0 + 2 hours); // waiting out the window does not help either
        assertFalse(_consume(CHAIN, 1));
        assertTrue(limiter.isPaused(CHAIN));
    }

    function testHiddenEmptyBucketDoesNotTripBreaker() public {
        assertTrue(_consume(CHAIN, 1_000));
        assertFalse(_consume(CHAIN, 5_000)); // far above threshold, but the bucket refuses first
        assertFalse(limiter.isPaused(CHAIN));
        assertEq(limiter.windowOutflow(CHAIN), 1_000);
        vm.warp(T0 + 1);
        assertFalse(_consume(CHAIN, 11));
        assertTrue(_consume(CHAIN, 10));
    }

    function testHiddenAmountAboveCapacityNeverPasses() public {
        assertFalse(_consume(CHAIN, 1_001));
        vm.warp(T0 + 30 days);
        assertFalse(_consume(CHAIN, 1_001));
        assertFalse(_consume(CHAIN, type(uint256).max));
        assertFalse(limiter.isPaused(CHAIN));
        assertTrue(_consume(CHAIN, 1_000));
    }

    function testHiddenWindowRollOverTiming() public {
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 1_800);
        assertTrue(_consume(CHAIN, 1_000));
        // last second of the window that started at configuration
        vm.warp(T0 + 3_599);
        assertEq(limiter.windowOutflow(CHAIN), 2_000);
        assertTrue(_consume(CHAIN, 500)); // 2500
        // first second after it: the view already reports a fresh window
        vm.warp(T0 + 3_600);
        assertEq(limiter.windowOutflow(CHAIN), 0);
        assertEq(limiter.available(CHAIN), 510);
        assertTrue(_consume(CHAIN, 510));
        assertEq(limiter.windowOutflow(CHAIN), 510);
        assertEq(uint256(limiter.getRoute(CHAIN).windowStart), T0 + 3_600);
        assertFalse(limiter.isPaused(CHAIN));
    }

    function testHiddenWindowStartsAtFirstConsumeAfterExpiry() public {
        vm.warp(T0 + 5 hours + 7); // long idle period
        assertTrue(_consume(CHAIN, 1_000));
        assertEq(uint256(limiter.getRoute(CHAIN).windowStart), T0 + 5 hours + 7);
        vm.warp(T0 + 5 hours + 7 + 3_599);
        assertEq(limiter.windowOutflow(CHAIN), 1_000);
        assertTrue(_consume(CHAIN, 1_000));
        assertFalse(_consume(CHAIN, 500)); // bucket is empty, not a trip
        assertFalse(limiter.isPaused(CHAIN));
        vm.warp(T0 + 5 hours + 7 + 3_600);
        assertEq(limiter.windowOutflow(CHAIN), 0);
    }

    function testHiddenSustainedDrainTripsBreaker() public {
        // An attacker takes whatever the bucket offers every 50 seconds.
        uint256 taken;
        uint256 t = T0;
        assertTrue(_consume(CHAIN, 1_000));
        taken = 1_000;
        bool tripped;
        for (uint256 i = 0; i < 10; i++) {
            t += 50;
            vm.warp(t);
            if (_consume(CHAIN, 500)) {
                taken += 500;
            } else {
                tripped = true;
                break;
            }
        }
        assertTrue(tripped);
        assertTrue(limiter.isPaused(CHAIN));
        assertEq(taken, 2_500); // never more than the threshold in the window
        assertEq(limiter.windowOutflow(CHAIN), 2_500);
    }

    function testHiddenPingPongStillCountsGrossOutflow() public {
        // Refilling the bucket with inbound transfers does not hide the outflow.
        for (uint256 i = 0; i < 2; i++) {
            assertTrue(_consume(CHAIN, 1_000));
            vm.prank(bridge);
            limiter.replenish(CHAIN, 1_000);
        }
        assertEq(limiter.available(CHAIN), 1_000);
        assertEq(limiter.windowOutflow(CHAIN), 2_000);
        assertFalse(_consume(CHAIN, 1_000));
        assertTrue(limiter.isPaused(CHAIN));
    }

    function testHiddenReplenishHugeAmountAndWhilePaused() public {
        assertTrue(_consume(CHAIN, 1_000));
        limiter.pause(CHAIN);
        vm.prank(bridge);
        limiter.replenish(CHAIN, type(uint256).max);
        assertEq(limiter.available(CHAIN), 1_000);
        vm.prank(bridge);
        limiter.replenish(CHAIN, 0);
        assertEq(limiter.available(CHAIN), 1_000);
        assertEq(limiter.windowOutflow(CHAIN), 1_000);
    }

    function testHiddenReconfigureSettlesOldRateFirst() public {
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 50); // 500 refilled at the old rate of 10/s
        limiter.configureRoute(CHAIN, 100_000, 1_000, 2_500, 1 hours);
        assertEq(limiter.available(CHAIN), 500); // not 50 * 1000
        vm.warp(T0 + 51);
        assertEq(limiter.available(CHAIN), 1_500); // the new rate applies from now on
        assertEq(limiter.windowOutflow(CHAIN), 1_000); // breaker window untouched
    }

    function testHiddenReconfigureCapsAndKeepsPause() public {
        vm.prank(guardian);
        limiter.pause(CHAIN);
        limiter.configureRoute(CHAIN, 300, 1, 2_500, 1 hours);
        assertEq(limiter.available(CHAIN), 300); // capped at the smaller capacity
        assertTrue(limiter.isPaused(CHAIN));
        limiter.unpause(CHAIN);
        assertTrue(_consume(CHAIN, 300));
        // raising the capacity does not conjure tokens
        limiter.configureRoute(CHAIN, 10_000, 1, 2_500, 1 hours);
        assertEq(limiter.available(CHAIN), 0);
        vm.warp(T0 + 5);
        assertEq(limiter.available(CHAIN), 5);
    }

    function testHiddenLoweredThresholdAppliesToCurrentWindow() public {
        assertTrue(_consume(CHAIN, 800));
        limiter.configureRoute(CHAIN, 1_000, 10, 900, 1 hours);
        assertTrue(_consume(CHAIN, 100)); // 900 == new threshold
        assertFalse(_consume(CHAIN, 1));
        assertTrue(limiter.isPaused(CHAIN));
    }

    function testHiddenBucketRefillsWhilePaused() public {
        assertTrue(_consume(CHAIN, 1_000));
        limiter.pause(CHAIN);
        limiter.pause(CHAIN); // idempotent
        vm.warp(T0 + 40);
        assertEq(limiter.available(CHAIN), 400);
        assertFalse(_consume(CHAIN, 100));
        assertEq(limiter.available(CHAIN), 400); // refusal took nothing
        limiter.unpause(CHAIN);
        assertTrue(_consume(CHAIN, 400));
    }

    function testHiddenUnpauseResetsWindow() public {
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 100);
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 200);
        assertFalse(_consume(CHAIN, 1_000)); // trip at 2000 + 1000
        vm.warp(T0 + 300);
        limiter.unpause(CHAIN);
        assertEq(limiter.windowOutflow(CHAIN), 0);
        assertEq(uint256(limiter.getRoute(CHAIN).windowStart), T0 + 300);
        assertTrue(_consume(CHAIN, 1_000));
        assertEq(limiter.windowOutflow(CHAIN), 1_000);
        // the new window ends one hour after the unpause, not after configuration
        vm.warp(T0 + 3_700);
        assertEq(limiter.windowOutflow(CHAIN), 1_000);
        vm.warp(T0 + 3_900);
        assertEq(limiter.windowOutflow(CHAIN), 0);
    }

    function testHiddenPauseAccessControl() public {
        vm.prank(mallory);
        vm.expectRevert(RouteRateLimiter.NotAuthorized.selector);
        limiter.pause(CHAIN);
        vm.prank(bridge);
        vm.expectRevert(RouteRateLimiter.NotAuthorized.selector);
        limiter.pause(CHAIN);
        vm.expectRevert(RouteRateLimiter.RouteNotConfigured.selector);
        limiter.pause(OTHER);

        vm.expectRevert(RouteRateLimiter.NotPaused.selector);
        limiter.unpause(CHAIN);
        vm.expectRevert(RouteRateLimiter.RouteNotConfigured.selector);
        limiter.unpause(OTHER);
        vm.prank(guardian);
        limiter.pause(CHAIN);
        vm.prank(guardian);
        vm.expectRevert(RouteRateLimiter.NotOwner.selector);
        limiter.unpause(CHAIN); // the guardian can stop, not restart
        assertTrue(limiter.isPaused(CHAIN));
    }

    function testHiddenRoutesAreIndependent() public {
        limiter.configureRoute(OTHER, 50, 0, 60, 10 minutes);
        assertTrue(_consume(OTHER, 50));
        vm.warp(T0 + 1 days);
        assertEq(limiter.available(OTHER), 0); // zero refill rate
        vm.prank(bridge);
        limiter.replenish(OTHER, 20);
        assertTrue(_consume(OTHER, 20)); // window rolled: outflow 20
        vm.prank(bridge);
        limiter.replenish(OTHER, 50);
        assertFalse(_consume(OTHER, 41)); // 61 > 60 trips OTHER only
        assertTrue(limiter.isPaused(OTHER));
        assertFalse(limiter.isPaused(CHAIN));
        assertTrue(_consume(CHAIN, 1_000));
        assertEq(limiter.windowOutflow(OTHER), 20);
        assertEq(limiter.windowOutflow(CHAIN), 1_000);
    }

    function testHiddenExtremeParametersDoNotOverflow() public {
        uint128 max = type(uint128).max;
        limiter.configureRoute(OTHER, max, max, max, type(uint64).max);
        assertTrue(_consume(OTHER, max));
        assertEq(limiter.available(OTHER), 0);
        vm.warp(T0 + 365 days);
        assertEq(limiter.available(OTHER), uint256(max)); // capped, no overflow
        assertFalse(_consume(OTHER, 1)); // threshold already reached -> trips
        assertTrue(limiter.isPaused(OTHER));
        assertEq(limiter.windowOutflow(OTHER), uint256(max));
    }
}

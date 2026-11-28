// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RouteRateLimiter.sol";

contract RouteRateLimiterTest is Test {
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

    function testNewRouteStartsFull() public view {
        assertEq(limiter.available(CHAIN), 1_000);
        assertEq(limiter.windowOutflow(CHAIN), 0);
        assertFalse(limiter.isPaused(CHAIN));
        assertEq(limiter.available(OTHER), 0);
        assertEq(limiter.owner(), address(this));
        assertEq(limiter.bridge(), bridge);
        assertEq(limiter.guardian(), guardian);
    }

    function testConsumeAndRefill() public {
        assertTrue(_consume(CHAIN, 600));
        assertEq(limiter.available(CHAIN), 400);
        vm.warp(T0 + 30);
        assertEq(limiter.available(CHAIN), 700);
        assertFalse(_consume(CHAIN, 701));
        assertTrue(_consume(CHAIN, 700));
        assertEq(limiter.available(CHAIN), 0);
        assertEq(limiter.windowOutflow(CHAIN), 1_300);
    }

    function testRefillIsCappedAtCapacity() public {
        assertTrue(_consume(CHAIN, 1_000));
        vm.warp(T0 + 99);
        assertEq(limiter.available(CHAIN), 990);
        vm.warp(T0 + 100);
        assertEq(limiter.available(CHAIN), 1_000);
        vm.warp(T0 + 3_000);
        assertEq(limiter.available(CHAIN), 1_000);
    }

    function testBreakerTripsAndStaysTripped() public {
        assertTrue(_consume(CHAIN, 1_000)); // outflow 1000
        vm.warp(T0 + 100);
        assertTrue(_consume(CHAIN, 1_000)); // 2000
        vm.warp(T0 + 200);
        assertFalse(_consume(CHAIN, 501)); // would be 2501 > 2500
        assertTrue(limiter.isPaused(CHAIN));
        assertEq(limiter.available(CHAIN), 1_000); // nothing was taken
        assertEq(limiter.windowOutflow(CHAIN), 2_000);
        assertFalse(_consume(CHAIN, 1)); // paused routes refuse everything
    }

    function testOwnerUnpausesAndWindowRestarts() public {
        vm.prank(guardian);
        limiter.pause(CHAIN);
        assertFalse(_consume(CHAIN, 1));
        limiter.unpause(CHAIN);
        assertTrue(_consume(CHAIN, 1));
        assertEq(limiter.windowOutflow(CHAIN), 1);
    }

    function testOnlyBridgeConsumes() public {
        vm.prank(mallory);
        vm.expectRevert(RouteRateLimiter.NotBridge.selector);
        limiter.consume(CHAIN, 1);
    }

    function testReplenishCapsAtCapacity() public {
        assertTrue(_consume(CHAIN, 900));
        vm.prank(bridge);
        limiter.replenish(CHAIN, 300);
        assertEq(limiter.available(CHAIN), 400);
        vm.prank(bridge);
        limiter.replenish(CHAIN, 5_000);
        assertEq(limiter.available(CHAIN), 1_000);
    }
}

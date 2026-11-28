// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwapOracle.sol";

contract TwapOracleTest is Test {
    TwapOracle public oracle;
    uint256 internal constant T0 = 1_700_000_000;

    function setUp() public {
        vm.warp(T0);
        oracle = new TwapOracle(8, 100);
    }

    function _feed() internal {
        vm.warp(T0 + 10);
        oracle.update(200);
        vm.warp(T0 + 30);
        oracle.update(400);
        vm.warp(T0 + 40);
    }

    function testInitialState() public view {
        assertEq(oracle.owner(), address(this));
        assertEq(uint256(oracle.cardinality()), 8);
        assertEq(uint256(oracle.index()), 0);
        assertEq(uint256(oracle.count()), 1);
        assertEq(oracle.price(), 100);
        (uint64 ts, uint192 cum) = oracle.observations(0);
        assertEq(uint256(ts), T0);
        assertEq(uint256(cum), 0);
        assertEq(oracle.consult(0), 100);
    }

    function testObservationsAccumulate() public {
        _feed();
        assertEq(uint256(oracle.index()), 2);
        assertEq(uint256(oracle.count()), 3);
        (uint64 ts1, uint192 cum1) = oracle.observations(1);
        assertEq(uint256(ts1), T0 + 10);
        assertEq(uint256(cum1), 1000);
        (uint64 ts2, uint192 cum2) = oracle.observations(2);
        assertEq(uint256(ts2), T0 + 30);
        assertEq(uint256(cum2), 5000);
        assertEq(oracle.currentCumulative(), 9000);
    }

    function testConsultFullWindow() public {
        _feed();
        // (100*10 + 200*20 + 400*10) / 40
        assertEq(oracle.consult(40), 225);
    }

    function testConsultInsideNewestInterval() public {
        _feed();
        assertEq(oracle.consult(10), 400);
        assertEq(oracle.consult(4), 400);
    }

    function testConsultInterpolatesBetweenObservations() public {
        _feed();
        // target = T0 + 15, cumulative there = 1000 + 200*5 = 2000, (9000 - 2000) / 25
        assertEq(oracle.consult(25), 280);
        // target = T0 + 5, cumulative there = 500, (9000 - 500) / 35 = 242.86 -> 242
        assertEq(oracle.consult(35), 242);
    }

    function testConsultTooOldReverts() public {
        _feed();
        vm.expectRevert(TwapOracle.ObservationTooOld.selector);
        oracle.consult(41);
    }

    function testOnlyOwnerUpdates() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(TwapOracle.NotOwner.selector);
        oracle.update(1);
    }
}

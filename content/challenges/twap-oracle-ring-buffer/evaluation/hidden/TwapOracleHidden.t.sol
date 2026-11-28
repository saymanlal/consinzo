// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TwapOracle.sol";

contract TwapOracleHiddenTest is Test {
    uint256 internal constant T0 = 1_700_000_000;

    function testHiddenZeroCardinalityReverts() public {
        vm.expectRevert(TwapOracle.ZeroCardinality.selector);
        new TwapOracle(0, 100);
    }

    function testHiddenRingWrapOverwritesOldest() public {
        vm.warp(T0);
        TwapOracle oracle = new TwapOracle(3, 100);
        vm.warp(T0 + 10);
        oracle.update(200);
        vm.warp(T0 + 30);
        oracle.update(400);
        assertEq(uint256(oracle.oldestTimestamp()), T0);
        vm.warp(T0 + 40);
        oracle.update(50); // wraps into slot 0
        assertEq(uint256(oracle.index()), 0);
        assertEq(uint256(oracle.count()), 3);
        assertEq(uint256(oracle.oldestTimestamp()), T0 + 10);
        (uint64 ts, uint192 cum) = oracle.observations(0);
        assertEq(uint256(ts), T0 + 40);
        assertEq(uint256(cum), 9000);

        vm.warp(T0 + 50);
        assertEq(oracle.currentCumulative(), 9500);
        // window starts exactly on the oldest observation: (9500 - 1000) / 40 = 212.5
        assertEq(oracle.consult(40), 212);
        // target = T0 + 20 lies between slots 1 and 2: cumulative 3000, (9500 - 3000) / 30
        assertEq(oracle.consult(30), 216);
        // target = T0 + 35 lies between slot 2 and the wrapped slot 0: 5000 + 4000*5/10 = 7000
        assertEq(oracle.consult(15), 166);
        vm.expectRevert(TwapOracle.ObservationTooOld.selector);
        oracle.consult(41);
        vm.expectRevert(TwapOracle.ObservationTooOld.selector);
        oracle.consult(50);
    }

    function testHiddenManyWrapsKeepWindowCorrect() public {
        vm.warp(T0);
        TwapOracle oracle = new TwapOracle(4, 10);
        // price i*10 is set at T0 + i*10, so interval i runs at price i*10
        for (uint256 i = 1; i <= 10; i++) {
            vm.warp(T0 + i * 10);
            oracle.update((i + 1) * 10);
        }
        // newest observation at T0+100 in slot 10 % 4 = 2; live: T0+70 .. T0+100
        assertEq(uint256(oracle.index()), 2);
        assertEq(uint256(oracle.count()), 4);
        assertEq(uint256(oracle.oldestTimestamp()), T0 + 70);
        vm.warp(T0 + 105);
        // cumulative(T0+100) = 10*(10+20+...+100) = 5500, now 5500 + 110*5 = 6050
        assertEq(oracle.currentCumulative(), 6050);
        // cumulative(T0+70) = 10*(10+..+70) = 2800 -> (6050 - 2800) / 35 = 92.857
        assertEq(oracle.consult(35), 92);
        // target T0+85: 3600 + 90*5 = 4050 -> 2000 / 20
        assertEq(oracle.consult(20), 100);
        vm.expectRevert(TwapOracle.ObservationTooOld.selector);
        oracle.consult(36);
    }

    function testHiddenSameTimestampUpdateDoesNotConsumeSlot() public {
        vm.warp(T0);
        TwapOracle oracle = new TwapOracle(4, 100);
        oracle.update(300); // same timestamp as the constructor observation
        assertEq(uint256(oracle.index()), 0);
        assertEq(uint256(oracle.count()), 1);
        assertEq(oracle.price(), 300);
        vm.warp(T0 + 10);
        oracle.update(500);
        oracle.update(700);
        assertEq(uint256(oracle.index()), 1);
        assertEq(uint256(oracle.count()), 2);
        (uint64 ts, uint192 cum) = oracle.observations(1);
        assertEq(uint256(ts), T0 + 10);
        assertEq(uint256(cum), 3000);
        vm.warp(T0 + 20);
        // 300 for 10s then 700 for 10s; the 100 and 500 prices never ran for a full second
        assertEq(oracle.consult(20), 500);
    }

    function testHiddenCardinalityOne() public {
        vm.warp(T0);
        TwapOracle oracle = new TwapOracle(1, 100);
        vm.warp(T0 + 10);
        oracle.update(200);
        assertEq(uint256(oracle.index()), 0);
        assertEq(uint256(oracle.count()), 1);
        assertEq(uint256(oracle.oldestTimestamp()), T0 + 10);
        vm.warp(T0 + 16);
        assertEq(oracle.consult(6), 200);
        assertEq(oracle.consult(0), 200);
        vm.expectRevert(TwapOracle.ObservationTooOld.selector);
        oracle.consult(7);
    }

    function testHiddenRoundingAndZeroPrice() public {
        vm.warp(T0);
        TwapOracle oracle = new TwapOracle(8, 7);
        vm.warp(T0 + 3);
        oracle.update(0);
        vm.warp(T0 + 10);
        oracle.update(5);
        vm.warp(T0 + 11);
        // cumulative now = 21 + 0 + 5 = 26
        assertEq(oracle.currentCumulative(), 26);
        assertEq(oracle.consult(11), 2); // 26 / 11
        // target T0+2: cumulative 21*2/3 = 14 -> (26 - 14) / 9 = 1
        assertEq(oracle.consult(9), 1);
        // target T0+5: inside the zero-price interval, cumulative 21 -> 5 / 6 = 0
        assertEq(oracle.consult(6), 0);
    }

    function testHiddenSecondsAgoBeyondGenesisReverts() public {
        vm.warp(1000);
        TwapOracle oracle = new TwapOracle(2, 1);
        vm.warp(1005);
        vm.expectRevert(TwapOracle.ObservationTooOld.selector);
        oracle.consult(2000);
    }

    function testHiddenNonOwnerCannotUpdate() public {
        TwapOracle oracle = new TwapOracle(2, 1);
        vm.prank(address(0xA11CE));
        vm.expectRevert(TwapOracle.NotOwner.selector);
        oracle.update(5);
        assertEq(oracle.price(), 1);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/WindowedTwapOracle.sol";

/// Minimal pair: accumulates price * time like a Uniswap V2 pair does on every reserve change.
contract MockPair {
    uint256 public price;
    uint256 public cumulative;
    uint256 public lastTimestamp;

    constructor(uint256 p) {
        price = p;
        lastTimestamp = block.timestamp;
    }

    function setPrice(uint256 p) external {
        cumulative += price * (block.timestamp - lastTimestamp);
        lastTimestamp = block.timestamp;
        price = p;
    }

    function currentCumulativePrice() external view returns (uint256) {
        return cumulative + price * (block.timestamp - lastTimestamp);
    }
}

abstract contract TwapFixture is Test {
    MockPair internal pair;
    WindowedTwapOracle internal oracle;
    uint256 internal t;
    uint256 internal blockNo;

    function _deploy() internal {
        t = block.timestamp;
        blockNo = block.number;
        pair = new MockPair(1e18);
        oracle = new WindowedTwapOracle(address(pair));
    }

    function _skip(uint256 secs) internal {
        t += secs;
        blockNo += 1;
        vm.warp(t);
        vm.roll(blockNo);
    }

    /// A keeper calling update() every five minutes.
    function _keeper(uint256 rounds) internal {
        for (uint256 i = 0; i < rounds; i++) {
            _skip(300);
            oracle.update();
        }
    }
}

contract WindowedTwapOracleHiddenTest is TwapFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenConstants() public view {
        assertEq(oracle.MIN_WINDOW(), 1800);
        assertEq(oracle.GRANULARITY(), 300);
        assertEq(oracle.CARDINALITY(), 12);
        assertEq(oracle.observationCount(), 1);
    }

    function testHiddenUpdateSpamCannotFlushHistory() public {
        _keeper(12);
        pair.setPrice(50e18);
        for (uint256 i = 0; i < 30; i++) {
            oracle.update();
            _skip(1);
        }
        // 30 seconds at 50x inside a window of at least 30 minutes.
        uint256 price = oracle.consult();
        assertLe(price, 2e18);
        assertEq(oracle.observationCount(), 13);
    }

    function testHiddenSustainedMoveIsAveragedOverTheWindow() public {
        _keeper(12);
        pair.setPrice(10e18);
        _skip(300);
        // Window starts at the observation taken 1800 s ago: 1500 s at 1.0 and 300 s at 10.0.
        assertEq(oracle.consult(), 2.5e18);
        oracle.update();
        assertEq(oracle.consult(), 2.5e18);
    }

    function testHiddenWindowBoundary() public {
        _skip(1799);
        vm.expectRevert(WindowedTwapOracle.InsufficientHistory.selector);
        oracle.consult();
        _skip(1);
        assertEq(oracle.consult(), 1e18);
    }

    function testHiddenSparseUpdatesUseTheOldObservation() public {
        // Nobody updates for two hours; the constructor observation is the only one.
        _skip(3600);
        pair.setPrice(3e18);
        _skip(3600);
        assertEq(oracle.consult(), 2e18);
    }

    function testHiddenRingWrapsAndKeepsRecentHistory() public {
        _keeper(24); // 2 hours, the ring has wrapped once
        pair.setPrice(3e18);
        _keeper(6); // 30 more minutes at 3.0
        assertEq(oracle.observationCount(), 31);
        assertEq(oracle.consult(), 3e18);
        _skip(299);
        assertFalse(oracle.update());
        assertEq(oracle.consult(), 3e18);
        (uint256 ts, ) = oracle.latestObservation();
        assertEq(ts, t - 299);
    }

    function testHiddenGranularityBoundary() public {
        _skip(299);
        assertFalse(oracle.update());
        _skip(1);
        assertTrue(oracle.update());
        (uint256 ts, uint256 cum) = oracle.latestObservation();
        assertEq(ts, t);
        assertEq(cum, 300e18);
    }

    function testHiddenTwoBlockManipulationAfterLongQuietPeriod() public {
        _keeper(40);
        oracle.update();
        pair.setPrice(1000e18);
        _skip(12);
        oracle.update();
        _skip(12);
        // 24 s at 1000x over at least 1800 s: at most about 14.4.
        assertLe(oracle.consult(), 15e18);
    }
}

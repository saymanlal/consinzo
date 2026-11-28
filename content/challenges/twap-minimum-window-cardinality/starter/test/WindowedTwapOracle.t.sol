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

contract WindowedTwapOracleTest is TwapFixture {
    function setUp() public {
        _deploy();
    }

    function testOneBlockManipulationIsBounded() public {
        _keeper(12); // one hour of history at price 1.0

        // Attacker: restart the window, pump the spot price 100x, hold it for one block.
        oracle.update();
        pair.setPrice(100e18);
        _skip(12);

        uint256 price = oracle.consult();
        assertLe(price, 2e18);
        assertGe(price, 1e18);
    }

    function testConsultNeedsMinimumHistory() public {
        _skip(600);
        oracle.update();
        _skip(60);
        vm.expectRevert(WindowedTwapOracle.InsufficientHistory.selector);
        oracle.consult();
    }

    function testUpdateIsThrottled() public {
        _skip(300);
        assertTrue(oracle.update());
        uint256 count = oracle.observationCount();
        assertFalse(oracle.update());
        _skip(12);
        assertFalse(oracle.update());
        assertEq(oracle.observationCount(), count);
    }

    function testStablePriceIsReportedExactly() public {
        _keeper(12);
        assertEq(oracle.consult(), 1e18);
        _skip(100);
        assertEq(oracle.consult(), 1e18);
    }
}

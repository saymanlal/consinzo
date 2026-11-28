// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICumulativePriceSource {
    /// @notice Integral of the spot price over time, up to the current block timestamp.
    function currentCumulativePrice() external view returns (uint256);
}

/// @title WindowedTwapOracle
/// @notice Time-weighted average price derived from a cumulative price source.
contract WindowedTwapOracle {
    uint256 public constant MIN_WINDOW = 30 minutes;
    uint256 public constant GRANULARITY = 5 minutes;
    uint256 public constant CARDINALITY = 12;

    struct Observation {
        uint256 timestamp;
        uint256 cumulative;
    }

    error InsufficientHistory();

    ICumulativePriceSource public immutable source;
    uint256 public observationCount;
    Observation private _last;

    constructor(address source_) {
        source = ICumulativePriceSource(source_);
        _record();
    }

    function latestObservation() public view returns (uint256 timestamp, uint256 cumulative) {
        Observation storage o = _last;
        return (o.timestamp, o.cumulative);
    }

    function update() external returns (bool recorded) {
        // TODO: anyone can restart the averaging window at any time.
        _record();
        return true;
    }

    function consult() external view returns (uint256 price) {
        // TODO: the window is whatever time has passed since the last update(), even one block.
        uint256 elapsed = block.timestamp - _last.timestamp;
        if (elapsed == 0) revert InsufficientHistory();
        return (source.currentCumulativePrice() - _last.cumulative) / elapsed;
    }

    function _record() private {
        _last = Observation(block.timestamp, source.currentCumulativePrice());
        observationCount += 1;
    }
}

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
    /// @dev Ring buffer. Observation number n (0-based) lives at index n % CARDINALITY.
    Observation[CARDINALITY] private _ring;

    constructor(address source_) {
        source = ICumulativePriceSource(source_);
        _record();
    }

    function latestObservation() public view returns (uint256 timestamp, uint256 cumulative) {
        Observation storage o = _ring[(observationCount - 1) % CARDINALITY];
        return (o.timestamp, o.cumulative);
    }

    function update() external returns (bool recorded) {
        // Stored observations are at least GRANULARITY apart. CARDINALITY of them therefore
        // span at least (CARDINALITY - 1) * GRANULARITY = 55 minutes, which always contains
        // one that is MIN_WINDOW old, and a caller cannot overwrite them all at once.
        (uint256 lastTimestamp, ) = latestObservation();
        if (block.timestamp - lastTimestamp < GRANULARITY) return false;
        _record();
        return true;
    }

    function consult() external view returns (uint256 price) {
        uint256 count = observationCount;
        uint256 stored = count < CARDINALITY ? count : CARDINALITY;
        // Walk from the newest observation backwards to the first one that is old enough.
        for (uint256 i = 1; i <= stored; i++) {
            Observation storage o = _ring[(count - i) % CARDINALITY];
            uint256 elapsed = block.timestamp - o.timestamp;
            if (elapsed >= MIN_WINDOW) {
                return (source.currentCumulativePrice() - o.cumulative) / elapsed;
            }
        }
        revert InsufficientHistory();
    }

    function _record() private {
        _ring[observationCount % CARDINALITY] = Observation(block.timestamp, source.currentCumulativePrice());
        observationCount += 1;
    }
}

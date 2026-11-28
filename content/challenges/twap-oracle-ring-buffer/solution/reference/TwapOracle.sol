// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title Time-weighted average price oracle backed by a ring buffer.
contract TwapOracle {
    struct Observation {
        uint64 timestamp;
        uint192 cumulative;
    }

    error NotOwner();
    error ZeroCardinality();
    error ObservationTooOld();

    event PriceUpdated(uint256 price, uint256 cumulative, uint256 timestamp);

    address public immutable owner;
    uint16 public immutable cardinality;
    uint16 public index;
    uint16 public count;
    uint256 public price;

    mapping(uint256 => Observation) public observations;

    constructor(uint16 cardinality_, uint256 initialPrice) {
        if (cardinality_ == 0) revert ZeroCardinality();
        owner = msg.sender;
        cardinality = cardinality_;
        price = initialPrice;
        observations[0] = Observation(uint64(block.timestamp), 0);
        count = 1;
    }

    function update(uint256 newPrice) external {
        if (msg.sender != owner) revert NotOwner();
        Observation memory newest = observations[index];
        if (block.timestamp > newest.timestamp) {
            // Close the interval that ran at the old price, then store it in the next slot.
            newest.cumulative += uint192(price * (block.timestamp - newest.timestamp));
            newest.timestamp = uint64(block.timestamp);
            uint16 next = uint16((uint256(index) + 1) % cardinality);
            observations[next] = newest;
            index = next;
            if (count < cardinality) count += 1;
        }
        price = newPrice;
        emit PriceUpdated(newPrice, newest.cumulative, block.timestamp);
    }

    function currentCumulative() public view returns (uint256) {
        Observation memory newest = observations[index];
        return newest.cumulative + price * (block.timestamp - newest.timestamp);
    }

    function oldestTimestamp() public view returns (uint64) {
        return observations[_oldestSlot()].timestamp;
    }

    function consult(uint32 secondsAgo) external view returns (uint256) {
        if (secondsAgo == 0) return price;
        if (secondsAgo > block.timestamp) revert ObservationTooOld();
        uint256 target = block.timestamp - secondsAgo;
        return (currentCumulative() - _cumulativeAt(target)) / secondsAgo;
    }

    /// @dev Slot of the oldest live observation: 0 until the ring is full, then the slot
    ///      right after the newest one.
    function _oldestSlot() internal view returns (uint256) {
        if (count < cardinality) return 0;
        return (uint256(index) + 1) % cardinality;
    }

    function _cumulativeAt(uint256 target) internal view returns (uint256) {
        Observation memory newest = observations[index];
        if (target >= newest.timestamp) {
            return newest.cumulative + price * (target - newest.timestamp);
        }

        uint256 oldest = _oldestSlot();
        if (target < observations[oldest].timestamp) revert ObservationTooOld();

        // Binary search over logical positions [0, count - 1], oldest first. The invariant is
        // obs(lo).timestamp <= target < obs(hi).timestamp.
        uint256 lo = 0;
        uint256 hi = uint256(count) - 1;
        while (hi - lo > 1) {
            uint256 mid = (lo + hi) / 2;
            if (observations[(oldest + mid) % cardinality].timestamp <= target) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        Observation memory a = observations[(oldest + lo) % cardinality];
        Observation memory b = observations[(oldest + hi) % cardinality];
        return
            a.cumulative +
            (uint256(b.cumulative - a.cumulative) * (target - a.timestamp)) /
            (b.timestamp - a.timestamp);
    }
}

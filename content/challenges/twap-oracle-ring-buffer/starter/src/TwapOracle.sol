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
        // TODO: reject a zero cardinality, store the price and write the first observation
        //       (block.timestamp, 0) into slot 0 with count = 1.
        owner = msg.sender;
        cardinality = cardinality_;
        initialPrice;
    }

    function update(uint256 newPrice) external {
        // TODO: owner only. If time has passed since the newest observation, accumulate
        //       price * elapsed and write a new observation into the next ring slot.
        //       Then set the new price and emit PriceUpdated.
        newPrice;
        revert("NOT_IMPLEMENTED");
    }

    function currentCumulative() public view returns (uint256) {
        // TODO: newest cumulative extended to block.timestamp at the current price.
        return 0;
    }

    function oldestTimestamp() public view returns (uint64) {
        // TODO: timestamp of the oldest observation still stored in the ring.
        return 0;
    }

    function consult(uint32 secondsAgo) external view returns (uint256) {
        // TODO: spot price for 0; otherwise (cumulative now - cumulative at target) / secondsAgo,
        //       interpolating between observations and reverting with ObservationTooOld
        //       when the window starts before the oldest observation.
        secondsAgo;
        return 0;
    }
}

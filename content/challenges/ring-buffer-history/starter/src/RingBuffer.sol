// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RingBuffer {
    error ZeroCapacity();
    error Empty();
    error IndexOutOfBounds(uint256 index, uint256 length);

    event Pushed(uint256 value, uint256 totalPushed);

    uint256 public capacity;
    uint256 public totalPushed;

    // TODO: add storage for the slots

    constructor(uint256 capacity_) {
        // TODO: reject a zero capacity and store it
    }

    function push(uint256 value) external {
        // TODO: write into the next slot (overwriting the oldest when full), emit Pushed
        revert("NOT_IMPLEMENTED");
    }

    function length() public view returns (uint256) {
        // TODO: min(totalPushed, capacity)
        return 0;
    }

    function at(uint256 index) external view returns (uint256) {
        // TODO: chronological read, 0 = oldest; revert with IndexOutOfBounds(index, length)
        return 0;
    }

    function latest() external view returns (uint256) {
        // TODO: newest value; revert with Empty() when nothing was pushed
        return 0;
    }

    function oldest() external view returns (uint256) {
        // TODO: oldest held value; revert with Empty() when nothing was pushed
        return 0;
    }

    function toArray() external view returns (uint256[] memory) {
        // TODO: all held values, oldest first
        return new uint256[](0);
    }
}

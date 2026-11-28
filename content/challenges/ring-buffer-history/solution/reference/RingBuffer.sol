// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RingBuffer {
    error ZeroCapacity();
    error Empty();
    error IndexOutOfBounds(uint256 index, uint256 length);

    event Pushed(uint256 value, uint256 totalPushed);

    uint256 public immutable capacity;
    uint256 public totalPushed;

    // slot index (0 .. capacity - 1) => value. The n-th push (counting from 0)
    // always lands in slot n % capacity.
    mapping(uint256 => uint256) private _slots;

    constructor(uint256 capacity_) {
        if (capacity_ == 0) revert ZeroCapacity();
        capacity = capacity_;
    }

    function push(uint256 value) external {
        uint256 pushed = totalPushed;
        // Once the buffer is full this slot holds the oldest value, which is
        // exactly the one that has to be dropped.
        _slots[pushed % capacity] = value;
        unchecked {
            pushed += 1;
        }
        totalPushed = pushed;
        emit Pushed(value, pushed);
    }

    function length() public view returns (uint256) {
        uint256 pushed = totalPushed;
        return pushed < capacity ? pushed : capacity;
    }

    function at(uint256 index) external view returns (uint256) {
        uint256 len = length();
        if (index >= len) revert IndexOutOfBounds(index, len);
        return _at(index, len);
    }

    function latest() external view returns (uint256) {
        uint256 len = length();
        if (len == 0) revert Empty();
        return _at(len - 1, len);
    }

    function oldest() external view returns (uint256) {
        uint256 len = length();
        if (len == 0) revert Empty();
        return _at(0, len);
    }

    function toArray() external view returns (uint256[] memory values) {
        uint256 len = length();
        values = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            values[i] = _at(i, len);
        }
    }

    /// @dev The held values are pushes number (totalPushed - len) .. (totalPushed - 1).
    ///      Push number n is stored in slot n % capacity.
    function _at(uint256 index, uint256 len) internal view returns (uint256) {
        return _slots[(totalPushed - len + index) % capacity];
    }
}

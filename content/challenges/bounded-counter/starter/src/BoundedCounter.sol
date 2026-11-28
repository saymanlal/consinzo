// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BoundedCounter {
    error InvalidBounds(uint256 min, uint256 max);
    error InitialOutOfBounds(uint256 initial);
    error AboveMax(uint256 max);
    error BelowMin(uint256 min);

    event ValueChanged(uint256 newValue);

    uint256 public min;
    uint256 public max;
    uint256 public value;

    constructor(uint256 min_, uint256 max_, uint256 initial) {
        // TODO: validate the bounds and the initial value, then store them
    }

    function increment() external {
        // TODO: same as add(1)
        revert("NOT_IMPLEMENTED");
    }

    function decrement() external {
        // TODO: same as sub(1)
        revert("NOT_IMPLEMENTED");
    }

    function add(uint256 amount) external {
        // TODO: revert with AboveMax(max) if value + amount would exceed max (no panics)
        revert("NOT_IMPLEMENTED");
    }

    function sub(uint256 amount) external {
        // TODO: revert with BelowMin(min) if value - amount would drop below min (no panics)
        revert("NOT_IMPLEMENTED");
    }
}

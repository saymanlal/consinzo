// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BoundedCounter {
    error InvalidBounds(uint256 min, uint256 max);
    error InitialOutOfBounds(uint256 initial);
    error AboveMax(uint256 max);
    error BelowMin(uint256 min);

    event ValueChanged(uint256 newValue);

    uint256 public immutable min;
    uint256 public immutable max;
    uint256 public value;

    constructor(uint256 min_, uint256 max_, uint256 initial) {
        if (min_ > max_) revert InvalidBounds(min_, max_);
        if (initial < min_ || initial > max_) revert InitialOutOfBounds(initial);
        min = min_;
        max = max_;
        value = initial;
    }

    function increment() external {
        _add(1);
    }

    function decrement() external {
        _sub(1);
    }

    function add(uint256 amount) external {
        _add(amount);
    }

    function sub(uint256 amount) external {
        _sub(amount);
    }

    function _add(uint256 amount) internal {
        uint256 current = value;
        // `max - current` cannot underflow because current <= max is an invariant.
        // Comparing against the remaining room avoids computing current + amount,
        // which could overflow and panic before the bound is checked.
        if (amount > max - current) revert AboveMax(max);
        unchecked {
            current += amount;
        }
        value = current;
        emit ValueChanged(current);
    }

    function _sub(uint256 amount) internal {
        uint256 current = value;
        // Same reasoning downwards: current >= min always holds.
        if (amount > current - min) revert BelowMin(min);
        unchecked {
            current -= amount;
        }
        value = current;
        emit ValueChanged(current);
    }
}

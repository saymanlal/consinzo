# Bounded Counter With Custom Errors

## Problem Statement

Implement `BoundedCounter` in `src/BoundedCounter.sol`. The counter holds a `uint256` that must
always satisfy `min <= value <= max`. The bounds are fixed in the constructor.

## Required Interface

```solidity
error InvalidBounds(uint256 min, uint256 max);
error InitialOutOfBounds(uint256 initial);
error AboveMax(uint256 max);
error BelowMin(uint256 min);

event ValueChanged(uint256 newValue);

constructor(uint256 min_, uint256 max_, uint256 initial);

function min() external view returns (uint256);
function max() external view returns (uint256);
function value() external view returns (uint256);

function increment() external;
function decrement() external;
function add(uint256 amount) external;
function sub(uint256 amount) external;
```

## Rules

1. Constructor: revert with `InvalidBounds(min_, max_)` if `min_ > max_` (equal bounds are allowed).
   Then revert with `InitialOutOfBounds(initial)` if `initial` is outside `[min_, max_]`.
2. `add(amount)` raises the value by `amount`. If the result would be greater than `max`, revert with
   `AboveMax(max)`. This must hold for every `amount`, including values close to
   `type(uint256).max`: the call must revert with `AboveMax`, never with an arithmetic panic.
3. `sub(amount)` lowers the value by `amount`. If the result would be less than `min` (including the
   case where `amount` is larger than the value itself), revert with `BelowMin(min)`.
4. `increment()` and `decrement()` behave exactly like `add(1)` and `sub(1)`.
5. Every successful call emits `ValueChanged(newValue)`. `add(0)` and `sub(0)` succeed.
6. Anyone may call the functions. A reverted call leaves the value unchanged.

## What the Tests Check

- Constructor validation and the stored bounds.
- Stepping to exactly `max` and exactly `min` works; one more step reverts with the right error and
  argument.
- Large amounts revert with the custom error, not a panic.
- A counter whose bounds are equal can never move.

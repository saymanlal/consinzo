# Fixed-Capacity Ring Buffer

## Problem Statement

Implement `RingBuffer` in `src/RingBuffer.sol`. The buffer has a fixed capacity chosen at
deployment. `push` stores a value; when the buffer is full the oldest value is discarded to make
room. Reads return values in chronological order: index `0` is the oldest value still held.

`push` must cost constant gas. Do not shift elements.

## Required Interface

```solidity
error ZeroCapacity();
error Empty();
error IndexOutOfBounds(uint256 index, uint256 length);

event Pushed(uint256 value, uint256 totalPushed);

constructor(uint256 capacity_);

function capacity() external view returns (uint256);
function totalPushed() external view returns (uint256);
function length() external view returns (uint256);

function push(uint256 value) external;
function at(uint256 index) external view returns (uint256);
function latest() external view returns (uint256);
function oldest() external view returns (uint256);
function toArray() external view returns (uint256[] memory);
```

## Rules

1. The constructor reverts with `ZeroCapacity()` if `capacity_ == 0`. The capacity never changes.
2. `push(value)` stores the value, increases `totalPushed` by one and emits
   `Pushed(value, totalPushed)` with the new total. If the buffer already holds `capacity` values,
   the oldest one is dropped. Anyone may push.
3. `length()` is the number of values currently held: `min(totalPushed, capacity)`.
4. `at(index)` returns the value at chronological position `index`, where `0` is the oldest held
   value and `length() - 1` the newest. It reverts with `IndexOutOfBounds(index, length)` when
   `index >= length()`.
5. `latest()` returns the most recently pushed value and `oldest()` the oldest held value. Both
   revert with `Empty()` when nothing has been pushed.
6. `toArray()` returns all held values, oldest first. It returns an empty array when nothing has
   been pushed.

## Example

Capacity 3, pushes `10, 20, 30, 40, 50`:

- after `30`: `toArray() == [10, 20, 30]`
- after `40`: `toArray() == [20, 30, 40]`
- after `50`: `toArray() == [30, 40, 50]`, `oldest() == 30`, `latest() == 50`, `at(1) == 40`

## What the Tests Check

- Contents and order before the buffer is full, exactly full, and after wrapping once and many
  times.
- A capacity of one.
- `Empty()` and `IndexOutOfBounds` with the correct arguments.
- Constructor validation.

# Running Statistics Aggregator

## Problem Statement

Implement `RunningStats` in `src/RunningStats.sol`. Anyone can submit unsigned integers. The
contract keeps summary statistics over everything submitted so far. It must not store the
individual values or loop over history.

## Required Interface

```solidity
error NoData();

event Submitted(address indexed by, uint256 value);

function count() external view returns (uint256);
function sum() external view returns (uint256);
function min() external view returns (uint256);
function max() external view returns (uint256);
function average() external view returns (uint256);

function submit(uint256 value) external;
function submitBatch(uint256[] calldata values) external;
```

## Rules

1. `submit(value)` records one value and emits `Submitted(msg.sender, value)`. Any `uint256` is a
   valid value, including `0`.
2. `submitBatch(values)` is equivalent to calling `submit` for each element in order (one event
   per element). An empty array does nothing.
3. `count()` is the number of values submitted and `sum()` their total. Both are `0` before the
   first submission.
4. `min()` and `max()` return the smallest and largest value submitted so far.
5. `average()` returns `sum / count` rounded down.
6. `min()`, `max()` and `average()` revert with `NoData()` while `count == 0`.
7. If the sum would exceed `type(uint256).max` the submission reverts (the default checked
   arithmetic is sufficient).

## What the Tests Check

- All five statistics after one value and after several values in different orders.
- The minimum when all values are non-zero, and the handling of an explicit `0`.
- The rounding of the average.
- `NoData()` before the first submission.
- Batch submission, including an empty batch.

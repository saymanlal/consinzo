# Basis-Points Math With Explicit Rounding

## Problem Statement

Implement `BpsMath` in `src/BpsMath.sol`. A basis point (bps) is one hundredth of a percent:
`10_000` bps is 100%, `250` bps is 2.5%. Solidity has no fractions, so every percentage calculation
must decide what happens to the remainder. This helper makes the choice explicit.

## Required Interface

```solidity
uint256 public constant BPS_DENOMINATOR = 10_000;

error InvalidBps(uint256 bps);

function mulBpsDown(uint256 amount, uint256 bps) external pure returns (uint256);
function mulBpsUp(uint256 amount, uint256 bps) external pure returns (uint256);
function splitFee(uint256 amount, uint256 feeBps) external pure returns (uint256 fee, uint256 net);
```

## Rules

1. All three functions revert with `InvalidBps(bps)` when the rate is greater than `10_000`.
   `0` and `10_000` are valid.
2. `mulBpsDown(amount, bps)` returns `amount * bps / 10_000` rounded down (floor).
3. `mulBpsUp(amount, bps)` returns the same quantity rounded up (ceiling). When the division is
   exact, both functions return the same value.
4. `splitFee(amount, feeBps)` returns `fee = mulBpsUp(amount, feeBps)` and `net = amount - fee`.
   `fee + net == amount` always holds.
5. The results must be mathematically exact for every `amount` up to `type(uint256).max`. The
   functions must not revert with an arithmetic overflow for any valid rate. In particular
   `mulBpsDown(type(uint256).max, 10_000)` returns `type(uint256).max`.

## Examples

| amount | bps | down | up |
| ------ | --- | ---- | -- |
| 12345 | 250 | 308 | 309 |
| 10000 | 25 | 25 | 25 |
| 1 | 1 | 0 | 1 |
| 999 | 10000 | 999 | 999 |

## What the Tests Check

- The examples above and other values with and without remainders.
- Rates of `0`, `10_000` and `10_001`.
- Very large amounts, including `type(uint256).max`.
- `fee + net == amount` and fee rounding in `splitFee`.

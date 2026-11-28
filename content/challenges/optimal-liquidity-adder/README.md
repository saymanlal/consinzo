# Optimal Add-Liquidity Helper for a Constant-Product Pair

## Problem Statement

A constant-product pair mints LP shares for whatever tokens it has received since its last
reserve update, and it credits the depositor with the *smaller* of the two proportional
contributions. Tokens sent in the wrong ratio are a gift to the existing LPs. Users
therefore never transfer to a pair directly: a helper works out the amounts that match the
current reserve ratio, enforces the user's minimums and deadline, moves exactly those
amounts and asks the pair to mint.

Implement that helper, `LiquidityAdder`, in `src/LiquidityAdder.sol`. The pair and the
tokens used by the tests are mocks that follow the `IPair` and `IERC20Minimal` interfaces
declared in the same file.

## Interface

```solidity
function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB);

function optimalAmounts(
    address pair,
    uint256 amount0Desired,
    uint256 amount1Desired,
    uint256 amount0Min,
    uint256 amount1Min
) public view returns (uint256 amount0, uint256 amount1);

function addLiquidity(
    address pair,
    uint256 amount0Desired,
    uint256 amount1Desired,
    uint256 amount0Min,
    uint256 amount1Min,
    address to,
    uint256 deadline
) external returns (uint256 amount0, uint256 amount1, uint256 liquidity);

error Expired();
error ZeroAddress();
error InsufficientAmount();
error InsufficientLiquidity();
error Insufficient0Amount();
error Insufficient1Amount();
error TransferFailed();
```

## Rules

### `quote`

1. Reverts with `InsufficientAmount()` when `amountA == 0`.
2. Otherwise reverts with `InsufficientLiquidity()` when `reserveA == 0` or `reserveB == 0`.
3. Returns `amountA * reserveB / reserveA`, rounding down.

### `optimalAmounts`

Reads `(reserve0, reserve1)` from `IPair(pair).getReserves()`. Balances of the pair are
never used: only the reported reserves define the ratio.

1. If both reserves are zero the pool is empty and the depositor sets the price: return
   `(amount0Desired, amount1Desired)`. The minimums are not checked in this case.
2. Otherwise compute `amount1Optimal = quote(amount0Desired, reserve0, reserve1)`
   (the reverts of `quote` propagate, so a pool with exactly one zero reserve reverts with
   `InsufficientLiquidity()`).
   - If `amount1Optimal <= amount1Desired`: revert with `Insufficient1Amount()` when
     `amount1Optimal < amount1Min`, otherwise return `(amount0Desired, amount1Optimal)`.
   - Else compute `amount0Optimal = quote(amount1Desired, reserve1, reserve0)`: revert with
     `Insufficient0Amount()` when `amount0Optimal < amount0Min`, otherwise return
     `(amount0Optimal, amount1Desired)`.

A returned amount never exceeds the corresponding desired amount.

### `addLiquidity`

Checks and effects, in this order:

1. Revert with `Expired()` when `block.timestamp > deadline` (a call at exactly `deadline`
   is allowed).
2. Revert with `ZeroAddress()` when `to == address(0)`.
3. Compute `(amount0, amount1)` exactly as `optimalAmounts` does.
4. Pull `amount0` of `pair.token0()` and `amount1` of `pair.token1()` from `msg.sender`
   **directly to the pair** with `transferFrom`. Revert with `TransferFailed()` if either
   call returns `false`. The helper itself must never hold tokens.
5. Call `pair.mint(to)` and return its result as `liquidity`.

The caller approves the helper for both tokens beforehand.

## What the tests check

- `quote` arithmetic, rounding and its two revert conditions.
- First deposit into an empty pool, and later deposits where token0 or token1 is the
  limiting side, including rounding with small reserves.
- Minimum amounts at the exact boundary, the deadline at the exact boundary.
- Only the optimal amounts leave the caller, the helper keeps no balance, LP shares go to
  `to`, a token returning `false` aborts the deposit, and donated (unsynced) pair balances
  do not change the ratio used.

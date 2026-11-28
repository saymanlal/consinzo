# Constant-Sum Stable Pool with Fees and Proportional Liquidity

## Problem Statement

Implement `ConstantSumPool` in `src/ConstantSumPool.sol`, an automated market maker for two
tokens that are meant to trade at par (same decimals, same value). The pool follows
`x + y = k`: a swap pays out the input amount minus a fee, as long as the pool holds enough of
the output token. The fee stays in the pool, so `k` grows and liquidity providers earn it.

Liquidity is provided and withdrawn in proportion to the current reserves and is represented by
internal, non-transferable shares.

## Interface

```solidity
constructor(address token0_, address token1_, uint256 feeBps_)

function getAmountOut(uint256 amountIn) public view returns (uint256)
function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut)
function addLiquidity(uint256 amount0Max, uint256 amount1Max)
    external returns (uint256 shares, uint256 amount0, uint256 amount1)
function removeLiquidity(uint256 shares, uint256 min0, uint256 min1)
    external returns (uint256 amount0, uint256 amount1)
```

Public state declared in the starter: `token0`, `token1`, `feeBps`, `reserve0`, `reserve1`,
`totalSupply`, `balanceOf(address)`, and the constant `MAX_FEE_BPS = 100`.

## Rules

1. The constructor reverts with `IdenticalTokens()` if both tokens are the same and with
   `FeeTooHigh()` if `feeBps_ > MAX_FEE_BPS`.
2. `reserve0` and `reserve1` are stored numbers updated only by the three state-changing
   functions. Tokens sent to the pool directly are ignored.
3. `getAmountOut(amountIn) = amountIn - fee` where
   `fee = ceil(amountIn * feeBps / 10_000)`.
4. `swap(tokenIn, amountIn, minAmountOut)`, checks in this order:
   - `InvalidToken()` if `tokenIn` is neither pool token;
   - `ZeroAmount()` if `amountIn == 0`;
   - `SlippageExceeded()` if `getAmountOut(amountIn) < minAmountOut`;
   - `InsufficientLiquidity()` if the output exceeds the reserve of the other token (taking the
     whole reserve is allowed).
   It pulls `amountIn` of `tokenIn`, sends the output in the other token, adds `amountIn` to
   the input reserve, subtracts the output from the output reserve and emits
   `Swap(sender, tokenIn, amountIn, amountOut)`.
5. `addLiquidity(amount0Max, amount1Max)`:
   - if `totalSupply == 0`: `shares = amount0Max + amount1Max`, and both maxima are pulled in
     full;
   - otherwise, for each token `i` with `reserve_i > 0` compute
     `amountMax_i * totalSupply / reserve_i` (rounded down); `shares` is the smaller of these
     candidates (or the only one, if one reserve is zero). The amount pulled for each token is
     `ceil(shares * reserve_i / totalSupply)`, which is `0` for a token whose reserve is zero;
   - reverts with `ZeroShares()` if `shares == 0`;
   - mints the shares, increases the reserves by the pulled amounts, emits
     `LiquidityAdded(provider, shares, amount0, amount1)`.
6. `removeLiquidity(shares, min0, min1)`:
   - `ZeroAmount()` if `shares == 0`; `InsufficientShares()` if the caller has fewer;
   - `amount_i = shares * reserve_i / totalSupply` (rounded down);
   - `SlippageExceeded()` if `amount0 < min0` or `amount1 < min1`;
   - burns the shares, decreases the reserves, pays both tokens (skipping zero transfers),
     emits `LiquidityRemoved(provider, shares, amount0, amount1)`.
7. **Invariant:** no operation decreases `(reserve0 + reserve1) / totalSupply`, and the pool's
   token balances are always at least its reserves.
8. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- 1:1 swaps minus the fee in both directions, the liquidity limit and slippage protection.
- Initial, proportional and single-sided-state liquidity deposits with exact amounts.
- That fees accrue to liquidity providers and the share value never decreases.
- Rounding directions for dust amounts and the revert order.

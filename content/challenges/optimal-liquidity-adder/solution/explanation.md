# Reference Solution Explanation

## Approach

The helper has no storage. Everything follows from one observation: a pair credits a
deposit with `min(amount0 / reserve0, amount1 / reserve1)` of the supply, so the only
deposit that wastes nothing satisfies `amount0 / amount1 == reserve0 / reserve1`.

`optimalAmounts` finds the largest such deposit inside the caller's desired amounts:

1. Assume all of token0 is used and compute the matching token1 amount with `quote`.
2. If that fits inside `amount1Desired`, token0 is the limiting side. The scaled-down side
   is token1, so that is the side protected by its minimum.
3. Otherwise token1 is the limiting side: use all of it and scale token0 down. Because both
   quotes round down, the scaled token0 amount cannot exceed `amount0Desired`.

Only the scaled-down side needs a minimum check. The other side equals the desired amount,
and a sensible caller never sets a minimum above what they offered.

The minimums are the caller's slippage protection: between signing and inclusion the
reserve ratio can move, and without a minimum the caller could be made to deposit at a
price they never agreed to. The deadline bounds how long a signed transaction stays valid.

`addLiquidity` transfers from the caller directly to the pair. Routing tokens through the
helper would cost two extra transfers and would leave dust behind if anything went wrong.
Both `transferFrom` results are checked, so a token that reports failure by returning
`false` cannot lead to LP shares being minted for tokens that never arrived.

## Pitfalls

- Reading the pair's token balances instead of `getReserves()`. Balances can be inflated by
  a donation; the pair prices deposits against its reserves.
- Treating a pool with one zero reserve as empty. Only `reserve0 == 0 && reserve1 == 0`
  skips the ratio; otherwise `quote` reverts with `InsufficientLiquidity()`.
- Using `>=` in the deadline check, which rejects a transaction mined exactly at the
  deadline.
- Checking the wrong minimum in each branch, or checking both minimums in the empty-pool
  case.
- Minting to `msg.sender` instead of `to`.

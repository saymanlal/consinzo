# Reference Solution Explanation

## Price

`priceOf` computes the floor from the start price and subtracts the linear decay. The decay
term rounds down, so the returned price is never below the ideal curve. Once `duration` has
elapsed the price is pinned to the floor.

## Take

A take is bounded twice:

1. by the collateral left (`slice = min(maxCollateral, lot)`), and
2. by the debt left. If the slice would cost more than the debt, the taker pays exactly the
   debt and the slice is recomputed as `debt * 1e18 / price`, rounded down.

`owe` is rounded up with `(x * y - 1) / d + 1`, so a taker cannot buy tiny slices whose cost
rounds to zero. The recomputed slice can only be smaller than the original one, so the
subtraction from `lot` cannot underflow.

## Closing

- `debt == 0`: the debt is fully recovered. Whatever is left in the lot belongs to the
  liquidated user and is transferred back in the same transaction.
- `lot == 0` with debt outstanding: nothing is left to sell, so the shortfall is added to
  `totalBadDebt` and kept on the auction record.

Both state updates happen before any token transfer (checks, effects, interactions).

## Pitfalls

- Charging `slice * price` even when it exceeds the debt over-collects from takers and
  leaves the house with quote that belongs to nobody.
- Rounding `owe` down allows free collateral in dust-sized takes.
- Forgetting the refund strands the user's leftover collateral in the contract.
- Reverting when the debt-capped slice is zero makes an auction with dust debt impossible
  to close.
- Checking `maxPrice` against the start price rather than the current price defeats the
  taker's slippage protection.

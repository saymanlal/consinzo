# Reference Solution Explanation

## One rule, applied twice

A position `(collateral, debt)` is acceptable when

```
debt <= borrowLimit(collateral) = (collateral * price / 1e18) * ltvBps / 10_000
```

`borrow` increases the left side and `withdrawCollateral` decreases the right side, so both
must re-evaluate the inequality on the state that would result. The reference exposes
`borrowLimit(uint256)` as a function of an amount so that `withdrawCollateral` can call it with
the collateral that would remain. `depositCollateral` and `repay` only move the position
further inside the limit and need no check.

## Rounding

Both divisions round down. That direction favours the protocol: the limit is never higher than
the real-valued one. The dust test shows the consequence: 1 wei of collateral at price 1.5 has
value 1 and limit 0.

## Other details

- `repay` computes `paid = min(amount, debt)` before pulling tokens, so over-approving and
  "repay max" never over-charge.
- `borrow` checks liquidity explicitly so that the caller gets `InsufficientLiquidity()`
  instead of an opaque token revert; the limit is checked first, as specified.
- `totalCollateral` and `totalDebt` are updated in the same statements as the per-user values.
- Storage is updated before every token transfer.

## Pitfalls

- Checking the limit in `withdrawCollateral` against the current collateral rather than the
  remaining collateral lets a borrower walk away with everything.
- Using `>=` in the limit check forbids borrowing the exact maximum.
- Computing `price * ltvBps / 10_000` first and applying it to the collateral changes the
  rounding and disagrees with the specified two-step formula for dust amounts.
- Subtracting `amount` from the debt without capping underflows for an over-payment.

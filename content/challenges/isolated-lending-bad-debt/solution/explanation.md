# Reference Solution Explanation

## Structure

The market is two share ledgers that meet in one place. Suppliers hold shares of
`totalSupplyAssets`; borrowers hold shares of `totalBorrowAssets`. Interest adds the same
number to both asset totals, so no per-user state is touched and accrual is O(1).

The quantity `totalSupplyAssets - totalBorrowAssets` is the cash the market should hold.
Every function keeps the real token balance at or above that number, which is why every
conversion rounds in the market's favour.

## Bad debt

A position whose collateral is zero can never be made healthy by a liquidator, because there
is nothing left to seize. If its debt stayed in `totalBorrowAssets`, the supply share price
would keep counting money that will never arrive, and the last suppliers to withdraw would
find no cash: a bank run where early leavers are paid in full.

The reference removes the debt in the same transaction that empties the collateral:

```
bad = min(toAssetsUp(leftoverShares), totalBorrowAssets)
totalBorrowAssets -= bad
totalSupplyAssets -= bad
totalBorrowShares -= leftoverShares
```

`totalSupplyShares` is unchanged, so every supply share loses the same fraction of its value
and the loss is shared pro rata. A supplier who deposits afterwards buys shares at the lower
price and is not affected.

## Pitfalls

- **Not accruing before liquidation or health checks.** Stale totals understate the debt,
  which makes the written-off amount too small and leaves phantom assets behind.
- **Writing off while collateral remains.** The remaining collateral can still repay debt.
- **Reducing only `totalBorrowAssets`.** Then liquidity (`supply - borrow`) appears to grow
  by the bad debt and withdrawals drain other suppliers' cash.
- **Rounding the wrong way.** Minting borrow shares rounded down, or charging repayments
  rounded down, lets a borrower shave a wei per call.
- **Underflow on the last repayment.** Rounded-up assets may exceed the tracked total by a
  wei; the subtraction is floored at zero.
- **Dividing by zero after a total loss.** The virtual share and asset keep conversions
  defined when a total reaches zero.

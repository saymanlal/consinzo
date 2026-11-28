# Reference Solution Explanation

## Normalized debt

A vault stores `normalizedDebt = debt / rate` at the time of drawing. The global `rate` only
grows, so `normalizedDebt * rate` is the current debt of every vault with a single storage
write per drip. `currentRate()` extends the stored rate to the present for views, and `drip`
makes it permanent.

## Fee minting

When the rate moves from `r0` to `r1`, total debt grows by `totalNormalizedDebt * (r1 - r0) / RAY`.
The same amount of stablecoin is minted to the engine. This keeps the identity
`totalSupply = total debt + badDebt` (up to rounding dust in the system's favour): every unit
in circulation is either owed by a vault or recorded as a loss.

## Rounding

- `mint` rounds normalized debt up, `repay` and partial liquidation round it down, and
  `debtOf` rounds up. A user can never mint a unit that is not owed and can never clear debt
  for less than it is worth.
- A payment that covers the whole debt clears the normalized debt exactly instead of
  dividing, otherwise one unit of dust could remain forever.

## Liquidation

The liquidator buys collateral at `price / penalty`. If the vault cannot deliver the
collateral for the requested repayment, the repayment is reduced (rounded up) to what the
remaining collateral is worth at that discount. When the collateral is gone, the leftover
debt has no backing: it is moved to `badDebt` and removed from `totalNormalizedDebt` so it
stops accruing fees. `heal` cancels bad debt against surplus by burning the engine's own
balance, and the owner cannot take surplus out while bad debt exists.

## Pitfalls

- Using the stored `rate` in a view without extending it understates debt between drips.
- Changing `ratePerSecond` without dripping first applies the new rate retroactively.
- Checking the ceiling against normalized debt ignores accrued fees.
- Leaving written-off debt in `totalNormalizedDebt` mints fees on debt that nobody owes.
- Sending seized collateral before burning the liquidator's stablecoin is a free option for
  a liquidator without funds.

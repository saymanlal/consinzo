# Reference Solution Explanation

## Two indices

With a single index both sides would be charged the same amount per unit, which is only
zero-sum when long and short open interest are equal. The reference charges the paying side
`perUnit` and credits the receiving side `total / receiverOpenInterest`, where `total` is
what the paying side's open interest produces. Each side has its own cumulative index, and a
position only ever looks at the index of the side it is on.

## Lazy settlement

A position stores the index value at its last settlement. Funding since then is
`|size| * (index - entry)`. Every function that changes size, margin or open interest first
calls `accrue()` (so the stored indices are current and computed with the old open
interest) and then `_settle` (so the position is charged at its old size). Only after that
is the position changed and its entry index reset.

## Rounding

Three divisions round against the traders: `total` rounds down, the receivers' per-unit
credit rounds down, and each payer's charge rounds up while each receiver's credit rounds
down. The sum of margins can therefore only fall behind the token balance, never exceed it.

## Empty sides and shortfall

If one side is empty there is nobody to pay or nobody to receive, so the indices stay still
while `lastAccrual` advances; otherwise the first trader on the empty side would inherit a
charge for time before it existed. When a payer cannot cover its charge, the receivers have
already been credited through their index, so the missing amount is recorded in `shortfall`
instead of being ignored. A full exchange would liquidate before this point; the counter
makes the hole explicit.

## Pitfalls

- Updating open interest before accruing applies the new size to the past.
- Resetting the entry index without paying out silently erases funding.
- Using the long index for a position that flipped to short in the same call.
- Casting negative `int256` values to `uint256` without taking the absolute value.

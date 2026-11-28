# Perpetual Funding Accounting with Cumulative Indices

## Problem Statement

Implement `FundingLedger` in `src/FundingLedger.sol`: the part of a perpetual market that
charges funding. There is no price and no PnL in this exercise. Traders deposit margin in a
quote token, hold a signed position size, and funding moves margin between the long side and
the short side over time.

Funding must be zero-sum. The paying side is charged a fixed amount per unit of size, and
what was collected is shared by the receiving side in proportion to size. Because the two
sides can have different open interest, each side has its own cumulative index.

State variables, errors, events and the constructor are provided in the starter.

## Units

- `size`: `int256`, `1e18` is one unit; positive is long, negative is short.
- `fundingRatePerSecond`: `int256`, quote tokens (WAD) that longs pay per whole unit per
  second. Negative means shorts pay.
- Indices: `int256`, quote tokens per whole unit. A position on side `s` owes
  `|size| * (index_s - entryFundingIndex) / 1e18`.
- `minMarginPerUnit`: quote tokens of margin required per whole unit of `|size|`.

## Accrual

`currentIndices()` returns `(cumulativeFundingLong, cumulativeFundingShort)` extended to
`block.timestamp`. With `elapsed = block.timestamp - lastAccrual`:

- If `elapsed == 0`, the rate is `0`, or either side has zero open interest, the stored
  values are returned unchanged. Time in which one side is empty is never charged.
- Otherwise the payers are the longs when the rate is positive and the shorts when it is negative:

```
perUnit      = |rate| * elapsed
total        = payerOpenInterest * perUnit / 1e18          (rounded down)
payerIndex  += perUnit
receiverIndex -= total * 1e18 / receiverOpenInterest       (rounded down)
```

`accrue()` stores these values, sets `lastAccrual = block.timestamp` and emits
`FundingAccrued` (it does nothing when no time has passed). `lastAccrual` advances even when
no funding was charged.

## Settlement

`pendingFunding(user)` uses `currentIndices()` and returns what the position owes:

- index difference `d >= 0`: `+ceil(|size| * d / 1e18)` (the position pays, rounded up);
- `d < 0`: `-floor(|size| * |d| / 1e18)` (the position receives, rounded down);
- `0` for a flat position.

Settling a position (after accruing) subtracts a positive amount from its margin or adds a
negative one, and sets `entryFundingIndex` to the current index of its side. If a payer owes
more than its margin, the margin becomes `0` and the uncovered part is added to `shortfall`.
`FundingSettled(user, owed)` is emitted for positions with a non-zero size.

## Functions

- `setFundingRate(newRate)`: owner only (`NotOwner`). Accrues at the old rate first.
- `settle(user)`: anyone; accrue then settle `user`.
- `deposit(amount)`: `ZeroAmount` on zero; accrue, settle the caller, pull tokens, add margin.
- `withdraw(amount)`: `ZeroAmount` on zero; accrue, settle; `InsufficientMargin` if
  `amount > margin` or if the remaining margin violates the requirement; pay out.
- `modifyPosition(sizeDelta)`: `ZeroAmount` on zero; accrue and settle the caller at the old
  size; remove the old size from its side's open interest and add the new size to its side
  (a position may flip sides in one call); set `entryFundingIndex` to the current index of
  the new side, or `0` when flat; then enforce the requirement; emit `PositionModified`.
- Margin requirement: `margin * 1e18 >= |size| * minMarginPerUnit`, otherwise `InsufficientMargin`.

## What the Tests Check

Exact margins after funding in both directions with unbalanced open interest, rounding in
favour of the ledger, flips, rate changes, late joiners, one-sided markets, the shortfall
counter, and that the token balance always covers the sum of margins.

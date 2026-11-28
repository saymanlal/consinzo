# Reference Solution Explanation

## Approach

`latestPrice()` does three things in a fixed order: validate the sign of the answer,
validate its age, then rescale it.

- **Sign first.** `answer` is an `int256`. Casting a negative value to `uint256` wraps to a
  number close to `2**256`, so the `answer <= 0` check has to happen before the cast. The
  README also fixes the order of the two checks, so an answer that is both invalid and
  stale reports `InvalidPrice()`.
- **Age.** `updatedAt == 0` means the round never completed. `updatedAt > block.timestamp`
  is rejected explicitly; without it `block.timestamp - updatedAt` would underflow and
  revert with `Panic(0x11)` rather than `StalePrice()`. The comparison is `> maxAge`, so an
  answer exactly `maxAge` seconds old is still valid.
- **Scaling.** The difference between the feed decimals and 18 can go either way. Computing
  `10 ** (18 - decimals)` unconditionally underflows for feeds with more than 18 decimals,
  so the two directions are handled in separate branches. Scaling down truncates.

`toQuote` multiplies before dividing. Dividing `baseAmount` by `10 ** baseDecimals` first
would turn every amount below one whole unit into zero.

## Pitfalls

- Using `uint256(answer)` before checking the sign.
- Assuming every feed has 8 decimals, or that decimals never exceed 18.
- Using `>=` for the staleness comparison, which rejects an answer that is exactly at the
  limit.
- Reading `decimals()` once in the constructor is acceptable for a real feed, but the
  reference reads it on each call so that it never disagrees with the aggregator.

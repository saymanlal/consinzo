# Reference Solution Explanation

## Approach

The oracle never stores prices in its history. It stores the running integral of price over
time (`cumulative`). The average over `[target, now]` is then
`(cumulative(now) - cumulative(target)) / (now - target)`, which needs only two lookups
regardless of how many updates happened inside the window.

- `update` first closes the interval that ran at the old price (`price * elapsed`), writes
  the resulting observation into the next slot of the ring, and only then replaces the price.
  Writing the observation before changing the price is what makes each stored value the
  integral of the prices that were actually in force.
- `_oldestSlot` is `0` while the ring is still filling and `(index + 1) % cardinality` once
  it is full, because the next slot to be overwritten is always the oldest one.
- `_cumulativeAt` handles three cases: at or after the newest observation (extrapolate with
  the spot price), before the oldest observation (`ObservationTooOld`), and in between
  (binary search over logical positions, then linear interpolation between the two
  neighbouring observations). Interpolation is exact because the price is constant between
  two consecutive observations.

## Pitfalls

- Accumulating with the *new* price instead of the old one shifts every average.
- Writing an observation on a same-timestamp update wastes a slot and creates two
  observations with equal timestamps, which makes interpolation divide by zero.
- Forgetting that the ring wraps: the oldest observation is not always slot `0`.
- Returning a value for a window that starts before the oldest observation silently
  shortens the window; the oracle must revert instead.
- All divisions round down. The interpolation rounds down first and the final division
  rounds down again, exactly as documented in the README.

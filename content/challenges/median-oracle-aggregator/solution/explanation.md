# Reference Solution Explanation

## Data model

Each reporter owns one slot, `reports[reporter] = (price, updatedAt)`. Reporting overwrites
the slot, so a reporter can never be counted twice. The reporter set is kept both as a
mapping (O(1) membership) and as an array (iteration); it is capped at 16 so that every
loop is bounded.

## Reading

`_evaluate()` is shared by `latestPrice()` and `tryLatestPrice()` so the two can never
disagree:

1. Collect the prices of fresh reports. Freshness is written as
   `updatedAt + maxAge >= block.timestamp`, which is the same condition as
   `block.timestamp - updatedAt <= maxAge` without a subtraction that could underflow.
2. Fewer than `minReports` fresh prices: `InsufficientReports`.
3. Sort (insertion sort, at most 16 elements) and take the median. For an even count the
   two middle values are averaged; both fit in 128 bits so the sum cannot overflow.
4. Count the fresh prices within `maxDeviationBps` of the median, comparing
   `diff * BPS <= median * maxDeviationBps` so no division is needed. Fewer than
   `minReports` in agreement: `DeviationTooHigh`.

## Why this is robust

With `n` fresh reports, moving the median outside the range of the honest values requires
controlling at least half of them. A minority of outliers leaves the median among the
honest values, and the agreement quorum then confirms that enough independent reports back
it. Conversely, when the honest reports themselves are scattered (or too few), the oracle
refuses to answer instead of publishing a number nobody stands behind. Reverting on *any*
outlier would be worse: a single faulty reporter could then switch the oracle off.

## Pitfalls

- Averaging instead of taking the median: one extreme report moves an average arbitrarily.
- Including stale reports when sorting; they must be filtered out before the median.
- Leaving the stored report in place on removal. The address then still counts (if the
  implementation iterates a stale list) or silently regains its old report when re-added.
- Allowing removals below `minReports`, which makes the oracle permanently unreadable.
- `>=` versus `>` at the age boundary and at the deviation boundary: both limits are
  inclusive.
- Not bounding `price`. With unbounded `uint256` prices `diff * BPS` can overflow and turn
  a read into a `Panic`, which a reporter could use to block the oracle.

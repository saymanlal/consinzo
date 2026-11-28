# Background: Median-Based Price Aggregation

## Why the median

Given sorted values `x[0] <= x[1] <= ... <= x[n-1]`, the median is `x[n/2]` for odd `n`
and the mean of `x[n/2 - 1]` and `x[n/2]` for even `n`. If fewer than half of the values
are controlled by an adversary, the median always lies between two honest values. A mean
has no such property: one value can move it anywhere.

## Freshness

Reporters can stop. A report carries the timestamp at which it was written and is ignored
once it is older than `maxAge`. Consumers must then decide what to do when too few fresh
reports remain; this oracle reverts (or returns `ok = false` from the non-reverting
variant) rather than serving an old price.

## Agreement

A median exists for any set of numbers, including `1`, `1000`, `1000000`. To avoid
publishing a value that the reports do not actually support, the oracle requires a quorum
of fresh reports within a relative band around the median:

```
|price - median| * 10_000 <= median * maxDeviationBps
```

Cross-multiplying avoids the rounding of an integer division.

## Sorting on chain

For a small bounded array, insertion sort in memory is simple and cheap. Sorting must be
done on a memory copy; storage is never reordered by a read.

## Bounded arithmetic

Restricting prices to 128 bits guarantees that sums of two prices and products with
`10_000` fit in 256 bits, so reads cannot fail with an arithmetic panic.

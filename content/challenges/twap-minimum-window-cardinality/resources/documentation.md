# Time-weighted average price oracles

## Cumulative prices

An AMM pair can cheaply maintain the running sum

```
cumulative(t) = sum of spotPrice * secondsItWasInEffect
```

updated whenever its reserves change. Any contract can sample this value at two times and
compute the average price in between by dividing the difference by the elapsed time. The
pair does the bookkeeping; the oracle only has to remember samples.

## Cost of manipulation

To distort the average an attacker must keep the spot price wrong for part of the window.
During that time arbitrageurs can trade against the mispriced pool, so every second costs
money. For a window `W`, a deviation factor `k` held for `d` seconds shifts the average by
roughly `(k - 1) * d / W`. A short window offers no protection: with `W` equal to one block,
the average is the spot price.

Since the merge, block proposers are known in advance and one entity can propose
consecutive blocks, which makes multi-block manipulation of short windows practical.

## Design parameters

| Parameter | Meaning | Trade-off |
| --- | --- | --- |
| window | minimum time the average covers | longer is safer but lags real moves |
| granularity | minimum spacing between stored samples | finer gives fresher windows, costs storage |
| cardinality | number of samples retained | must satisfy `(cardinality - 1) * granularity >= window` |

## Rules for a robust sample store

1. Samples may be added by anyone, but not more often than the granularity.
2. Keep enough samples that one older than the window always exists once the oracle has
   warmed up.
3. Never let a caller choose or shorten the window.
4. Refuse to answer during warm-up rather than answering with a short window.

## Consumers

A consumer should treat a reverting oracle as "no price" and stop risk-increasing actions
such as borrowing, instead of falling back to a spot price.

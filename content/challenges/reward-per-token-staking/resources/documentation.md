# Reward-per-Token Accounting

## The problem

A pool pays `R` tokens per second to all stakers in proportion to stake. Stakes change at
arbitrary times. Iterating over all stakers on every change is impossible on-chain, so the
distribution has to be computed lazily and in constant time.

## The idea

Define the cumulative reward per staked token

```
rpt(t) = sum over intervals of  R * dt / totalSupply
```

While a user's balance `b` is constant, the user earns `b * (rpt(t2) - rpt(t1))`. A user's
balance only changes in transactions sent by that user, so it is enough to:

1. advance `rpt` to "now" (global update), then
2. add `b * (rpt - rptPaid[user])` to the user's stored rewards and set `rptPaid[user] = rpt`
   (user settlement),

before the balance changes. Both steps are O(1).

## Fixed-point scaling

`R * dt / totalSupply` is usually far below 1, so the accumulator is stored multiplied by
`1e18` and divided out when the user amount is computed. Truncation always rounds user amounts
down, which means the pool can only be left with dust, never be short.

## Reward periods

Rewards are streamed over a period of fixed length: `rewardRate = amount / duration`, and
accrual stops at `periodFinish`. Adding rewards during a running period re-spreads the
undistributed remainder plus the new amount over a new full period.

## Edge cases to think about

- No stakers during part of a period: the accumulator cannot advance (division by zero), so
  that part of the budget is not attributed.
- A notification long after the previous period ended.
- Very small stakes next to very large ones (rounding).

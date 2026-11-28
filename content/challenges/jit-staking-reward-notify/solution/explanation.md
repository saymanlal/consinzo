# Why the redesign works

## The flaw is the distribution model

The starter treats a reward deposit as an instantaneous event: `amount / totalStaked` is
added to the accumulator at once. Entitlement is then decided by a snapshot of one block,
and a snapshot can be bought. The attacker's stake exists for a few transactions, carries no
market or lock-up risk, and dilutes long-term stakers by whatever factor the attacker can
fund (a flash loan makes that factor very large).

No access-control or ordering fix inside the same model helps. As long as rewards land in
one block, someone can arrange to be there.

## Streaming

The reference converts each deposit into a rate:

```
rewardRate   = amount / DURATION                         (no period running)
rewardRate   = (amount + remaining * oldRate) / DURATION (top-up)
periodFinish = now + DURATION
```

and the accumulator grows only with time:

```
rewardPerToken = stored + (min(now, periodFinish) - lastUpdateTime) * rewardRate * 1e18 / totalStaked
```

At the moment of notification no time has passed, so nobody's `earned` changes. A staker's
share of the reward is now the integral of `stake / totalStaked` over the period. Staking
for one block earns one block's worth; earning most of the reward requires being most of
the pool for most of a week.

## Details that matter

- `notifyRewardAmount` runs the global checkpoint first, so the time before the call is paid
  at the old rate (the same rule as for any rate change).
- `lastTimeRewardApplicable()` caps accrual at `periodFinish`. Without the cap the pool would
  keep paying at the last rate forever and become insolvent.
- Integer division rounds the rate down, so `rewardRate * DURATION <= amount + leftover`.
  The dust stays in the contract.
- With `totalStaked == 0` the accumulator does not move. Rewards for that time remain
  unallocated instead of causing a division by zero.

## Alternatives and why they are weaker

Minimum staking periods, withdrawal delays or same-block checks raise the cost of the
sandwich but keep the snapshot model; an attacker willing to hold for the minimum period
still captures a full reward for a fraction of the exposure.

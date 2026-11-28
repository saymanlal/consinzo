# Lazy reward accumulators and why every parameter change is a checkpoint

## The accumulator

Paying every staker every second is impossible on-chain, so staking pools track one global
number, the cumulative reward per staked token:

```
rewardPerToken(t) = sum over time of rate(t) * dt / totalStaked(t)
```

An account's reward between two moments is `stake * (rewardPerToken(now) - rewardPerToken(then))`,
provided its stake was constant in between. Pools therefore settle an account whenever its
stake changes.

## Laziness and its invariant

The global value is not updated every second either. The contract stores the value at
`lastUpdateTime` and extrapolates:

```
current = stored + (now - lastUpdateTime) * rate / totalStaked
```

The extrapolation assumes `rate` and `totalStaked` were constant since `lastUpdateTime`.
Hence the invariant: **before changing any input of the formula, fold the elapsed interval
into the stored value.** Inputs include the total stake, the rate, a reward period end, a
boost multiplier, or anything else the formula reads.

## Consequences of skipping the checkpoint

- Rate increased: past time is over-paid. Rewards credited exceed rewards funded, and the
  shortfall lands on whoever claims last.
- Rate decreased: past time is under-paid; users lose rewards they could have claimed one
  block earlier.
- An insider who knows a rate change is coming can time stakes around it.

## Testing idea

For any administrative setter, assert that `earned(user)` is identical immediately before and
immediately after the call. A setter that changes what users have already earned is a bug.

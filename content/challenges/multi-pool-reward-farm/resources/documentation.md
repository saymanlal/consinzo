# Multi-Pool Reward Distribution

## From one pool to many

A single staking pool distributes `R` tokens per second pro rata to stake using a cumulative
"reward per share" value. A farm generalises this: the emission `R` is first split between
pools by weights (allocation points), then each pool distributes its part to its own stakers.

```
pool reward per second = R * allocPoint / totalAllocPoint
```

## accRewardPerShare and rewardDebt

Each pool has an accumulator of reward per staked token. A user's entitlement is

```
pending = amount * accRewardPerShare - rewardDebt
```

where `rewardDebt` is "what this amount would have earned had it been staked since the pool was
created, measured at the user's last interaction". Subtracting it removes the rewards from
before the user joined and the rewards already paid. The rule for every user action is:

1. update the pool;
2. pay `pending`;
3. change `amount`;
4. set `rewardDebt = amount * accRewardPerShare`.

## Changing weights

The accumulators are updated lazily, so at any time some seconds have elapsed that are not yet
reflected in a pool. Those seconds must be priced with the weights that were in force. Hence:
update every pool, then change the weights. Forgetting this is a classic farm bug that lets a
weight change reassign past rewards.

## Precision

The accumulator is multiplied by a large constant before dividing by the total stake. With
18-decimal tokens, `1e18` keeps the truncation error negligible while leaving ample headroom in
256 bits.

## Funding

The farm in this exercise does not mint. It pays from a balance provided up front, so the
operator has to fund it for the planned emission.

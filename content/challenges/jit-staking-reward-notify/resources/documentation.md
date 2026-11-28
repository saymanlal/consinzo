# Just-in-time liquidity and reward streaming

## Snapshot rewards invite sandwiches

Any mechanism that pays a lump sum to "current holders" has the same weakness: holding at
one instant is cheap. The pattern appears with staking rewards, fee distributions, airdrop
snapshots and liquidity incentives. The attacker's sequence is always

```
enter with large size  ->  reward event  ->  exit
```

and with public mempools or predictable schedules, all three steps fit into one block.
Honest participants who carried the risk for the whole epoch are diluted.

## Time-weighted distribution

The standard remedy, popularised by the Synthetix `StakingRewards` contract, is to pay
rewards at a constant rate over a period:

- `notifyRewardAmount(amount)` sets `rewardRate = amount / DURATION` and
  `periodFinish = now + DURATION`;
- the reward-per-token accumulator increases by `rate * dt / totalStaked`;
- accounts are settled against the accumulator when their stake changes.

A participant's reward is then proportional to stake multiplied by time. Capturing a large
share requires capital to be committed for a large part of the period.

## Handling top-ups

If rewards arrive while a period is running, the undistributed remainder is
`(periodFinish - now) * rewardRate`. Add it to the new amount, divide by `DURATION` and
restart the period. Always checkpoint the accumulator before changing the rate.

Note a governance consideration: each top-up extends the period, so many tiny notifications
can stretch a reward thinly. That is why the function is restricted to a distributor.

## Invariants worth testing

- `earned(x)` is unchanged by a notification in the same block.
- After `periodFinish`, `earned` stops growing.
- Sum of all payouts is at most the sum of all notified amounts.
- `rewardRate * DURATION` is at most the reward balance attributable to the current period.

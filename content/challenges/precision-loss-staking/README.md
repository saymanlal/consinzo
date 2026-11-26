# Fix Division-Before-Multiplication Precision Loss

`RewardPool.earned(user)` currently computes `(stake[user] / totalStaked) * totalReward`, which truncates to `0` whenever `stake[user] < totalStaked`.

## Objective
Multiply before dividing and preserve precision.
# Mitigate Spot AMM Oracle Price Manipulation

`OracleLending` queries `amm.spotPrice()` directly to value collateral. If a flash-loan attacker skews `amm.spotPrice()` in a single block, they can borrow more than fair value.

## Objective
Reject borrow requests when `spotPrice` deviates by more than 10% from `twapPrice`, and value collateral using `min(spotPrice, twapPrice)`.
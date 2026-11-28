# CDP Engine Notes

## Collateralised debt positions

A CDP system issues a stablecoin as debt against locked collateral. The system is solvent
while every vault holds collateral worth more than its debt by a margin, the liquidation
ratio. When a vault falls below that margin anyone may repay part of its debt and receive
collateral at a discount, the liquidation penalty.

## Rate accumulators

Charging interest by updating every vault is impossible on-chain. Instead a single
accumulator `rate` is multiplied forward in time and each vault stores its debt in units
that are divided by the accumulator. Present debt is `normalizedDebt * rate`. This engine
applies a simple (linear) rate inside one accrual period and compounds between periods,
which keeps the arithmetic exact and easy to test.

## Fixed-point units

A WAD has 18 decimals and a RAY 27. Rates use RAYs because per-second rates are tiny and
need the extra precision. When multiplying two fixed-point numbers, divide by the unit once;
decide for each division which side the rounding error must favour.

## Bad debt

If the price falls faster than liquidators act, a vault's collateral can be worth less than
its debt. After the collateral is sold the remainder is an uncovered liability. Systems keep
an explicit counter for it and cancel it against income (stability fees) before any surplus
can be distributed.

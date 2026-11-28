# Fixed-APR Staking

## Simple interest per second

An annual percentage rate (APR) of `r` paid as simple interest means that a principal `P`
earns `P * r * t / YEAR` over `t` seconds. With the rate in basis points (1 bp = 0.01%):

```
interest = P * aprBps * t / (10_000 * 365 days)
```

Solidity has no fractional numbers, so the division truncates. Performing every multiplication
before the single division keeps the truncation below one base unit per calculation.

## Lazy accrual

Nothing happens on-chain between transactions. Contracts therefore record a timestamp and
compute what "would have accrued" the next time the user interacts. The rule is: bring the
stored amount up to date **before** changing any input of the formula (here, the principal).

## Shared balances

When a contract holds user deposits and its own reward budget in the same token, the token
balance alone cannot tell them apart. Keep an explicit counter for user funds and treat only
the difference as spendable by the protocol.

## Time units

`365 days` is a compile-time constant equal to 31,536,000 seconds. `block.timestamp` is the
block's Unix time in seconds.

# Reference Solution Explanation

## Root cause

```solidity
return amount / BPS * feeBps;
```

Solidity evaluates left to right and integer division discards the remainder. The
expression charges the fee on `floor(amount / 10_000) * 10_000` instead of on `amount`:

| amount | intended fee at 250 bps | starter fee |
| --- | --- | --- |
| 9 999 | 249 | 0 |
| 12 345 | 308 | 250 |
| 19 999 | 499 | 250 |

A payer who splits a payment into pieces below 10 000 wei pays nothing. With tokens that
have few decimals the same bug is far more expensive than it looks in wei.

## Fix

```solidity
return amount * feeBps / BPS;
```

Multiplying first keeps every digit until the last step. The single remaining division
rounds down by less than one unit, which is the documented behaviour.

## Overflow

`feeBps <= 1_000`, so `amount * feeBps` overflows only for amounts above roughly 1.1e74.
Solidity 0.8 would revert rather than wrap. For contracts where the multiplier can be
large (for example 1e18 fixed-point prices), use a full-precision `mulDiv`.

## Pitfalls

- Rounding the fee up changes the documented result and breaks `quoteFee(39) == 0`.
- Fixing `pay` but leaving `quoteFee` unchanged (or the reverse) makes the quoted and the
  charged fee disagree. `pay` should call `quoteFee`.

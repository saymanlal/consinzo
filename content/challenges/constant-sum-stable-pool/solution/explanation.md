# Reference Solution Explanation

## Swap

Both tokens are valued at par, so the price is 1 and a swap is
`amountOut = amountIn - fee`. The fee is `ceil(amountIn * feeBps / 10_000)`; rounding up means
dust swaps cannot avoid it. The fee is simply not paid out, so after a swap
`reserve0 + reserve1` has grown by exactly the fee. The only capacity limit is the reserve of
the output token; unlike a constant-product pool, a constant-sum pool can be emptied of one
token completely.

## Liquidity

The value of the pool is `reserve0 + reserve1`, but deposits cannot be accepted in arbitrary
proportions: a provider could add the token that is abundant, immediately withdraw a pro-rata
mix, and would have swapped without paying the fee (and without the reserve limit). Deposits
after the first one are therefore proportional:

```
shares   = min over tokens with reserve_i > 0 of  amountMax_i * supply / reserve_i   (down)
amount_i = ceil(shares * reserve_i / supply)
```

Skipping tokens with a zero reserve is what makes deposits possible while one side is drained;
in that state a deposit consists of the other token only.

`ceil(floor(aMax * S / r) * r / S) <= aMax`, so the pulled amount never exceeds the caller's
maximum, which acts as slippage protection. Withdrawals pay `shares * reserve_i / supply`
rounded down and take explicit minima.

## Invariant

Let `V = (reserve0 + reserve1) / totalSupply`.

- swap: numerator grows by the fee, denominator unchanged;
- add: each pulled amount is at least `shares * reserve_i / supply`, so the new ratio is at
  least the old one;
- remove: each paid amount is at most the pro-rata amount, so the remaining ratio is at least
  the old one.

Hence `V` never decreases, which the hidden tests check after every step of a mixed sequence.
When the last shares are burned the amounts equal the full reserves, so no dust is stranded and
`totalSupply == 0` implies empty reserves (the first-deposit branch relies on this).

## Other decisions

- Reserves are stored, not read from token balances, so donations cannot be used to change
  what a deposit or a swap computes.
- State is written before any token transfer; zero transfers are skipped.
- The specified check order in `swap` puts the cheap user-error checks before the
  liquidity check.

## Limits of the model

A constant-sum pool keeps quoting 1:1 even if one token loses its peg, at which point
arbitrageurs drain the sound token. Production stable pools blend constant-sum with
constant-product for that reason.

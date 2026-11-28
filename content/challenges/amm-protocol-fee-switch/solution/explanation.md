# Reference Solution Explanation

## Why sqrt(k)

Swap fees are left in the reserves, so `k = reserve0 * reserve1` grows while the LP supply is
unchanged. The value of the pool per LP share is proportional to `sqrt(k) / totalSupply`, so
`sqrt(k) / sqrt(kLast)` is the growth factor of every share since the last liquidity event.

## Deriving the mint formula

Let `S` be the supply, `r = rootK` and `l = rootKLast`. LPs earned the fraction
`(r - l) / r` of the pool as fees. The protocol should own one sixth of that after its
shares are minted:

```
m / (S + m) = (1/6) * (r - l) / r   =>   m = S * (r - l) / (5 * r + l)
```

Minting shares instead of moving tokens costs nothing during swaps and leaves `k` untouched.

## Ordering

`_mintFee` must run before the caller's liquidity is computed, on the reserves and supply
from before the change. Otherwise the caller either escapes the dilution (burn) or pays for
fee growth earned by others (mint). `kLast` is refreshed after the reserves change, because
a deposit or withdrawal changes `k` without being fee income.

## Switch transitions

- Off: `kLast` is reset to zero at the next liquidity event. If it were left stale, turning
  the switch back on would charge all growth since the stale value.
- On with `kLast == 0`: nothing can be measured yet, so the event only records `kLast`.

## Pitfalls

- Using `k` instead of `sqrt(k)` charges roughly twice the intended fee.
- Updating `kLast` in `swap` erases the growth before it is charged.
- Reading `totalSupply` before `_mintFee` makes the caller's result ignore the dilution.
- Reading token balances instead of tracked reserves lets donations be counted as fee growth
  in the caller's favour; this pair keeps its own reserves.

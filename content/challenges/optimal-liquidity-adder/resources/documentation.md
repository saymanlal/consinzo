# Background: Adding Liquidity to a Constant-Product Pair

## How a pair mints

A Uniswap-V2-style pair tracks `reserve0` and `reserve1`. Its `mint(to)` function does not
take amounts. It looks at how much of each token it holds beyond its reserves and mints

```
liquidity = min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)
```

(for the first deposit, the geometric mean of the two amounts). The smaller ratio wins.
Whatever was sent beyond that ratio stays in the pool and belongs to all LPs.

## The helper's job

Given desired amounts `(d0, d1)` and reserves `(r0, r1)`:

- `quote(d0, r0, r1) = d0 * r1 / r0` is the token1 amount worth `d0`.
- If it is at most `d1`, deposit `(d0, quote)`.
- Otherwise deposit `(quote(d1, r1, r0), d1)`.

## Slippage and deadline

The reserve ratio can change before the transaction executes. `amount0Min` and
`amount1Min` put a floor under the amount that gets scaled down, which is equivalent to a
bound on the price the caller accepts. `deadline` stops a transaction from being held and
executed much later.

## ERC-20 return values

EIP-20 `transferFrom` returns a `bool`. Some tokens signal failure by returning `false`
instead of reverting, so the return value has to be checked before relying on the transfer.

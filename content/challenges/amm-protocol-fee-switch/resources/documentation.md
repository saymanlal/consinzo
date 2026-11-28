# Protocol Fee Switch Notes

## Constant-product recap

A pair holds reserves `x` and `y`. A swap of `dx` with a 0.30% fee returns
`dy = dx * 997 * y / (x * 1000 + dx * 997)`. Because the fee stays in the pool, `x * y`
increases with every swap.

## Liquidity shares

The first depositor receives `sqrt(x * y)` shares minus a small locked amount, so the share
price cannot be inflated cheaply. Later depositors receive shares in proportion to the
reserves they add. One share is a claim on `reserve / totalSupply` of each token.

## Measuring fee income

`sqrt(x * y)` scales linearly with pool size. Dividing it by the share supply gives a value
per share that only increases through fees. Between two liquidity events the supply is
constant, so the ratio `sqrt(k) / sqrt(kLast)` is exactly the fee growth per share.

## Charging by dilution

Instead of transferring tokens on every swap, the protocol mints itself new shares when
liquidity next changes. Existing holders are diluted by the protocol's cut. The formula
`S * (rootK - rootKLast) / (5 * rootK + rootKLast)` gives the protocol one sixth of the
growth, which is 0.05% of volume out of the 0.30% fee.

## Integer square root

The Babylonian method converges to `floor(sqrt(y))` for unsigned integers: start from
`x = y / 2 + 1` and iterate `x = (y / x + x) / 2` while the estimate decreases.

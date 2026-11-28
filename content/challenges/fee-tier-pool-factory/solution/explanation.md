# Reference Solution Explanation

## Factory

- `createPool` sorts the pair before any lookup, so `(A, B, fee)` and `(B, A, fee)` hit the
  same slot. The pool address is then written under both orders so `getPool` is symmetric.
- The checks run in the documented order. Sorting before the zero-address check means only
  `token0` has to be compared against zero, because zero is the smallest address.
- `isPool` is the registry that `collectProtocolFees` trusts. Without it the owner could be
  tricked into calling an arbitrary contract that merely looks like a pool.
- `protocolFeeBps` lives in the factory and is read by pools at swap time, so one
  transaction changes the split for every pool without touching past accruals.

## Pool

The pool keeps three numbers per token: the reserve, the protocol balance and the lifetime
fee counter. The token balance always equals `reserve + protocolFees`.

For a swap the input is split as

```
feeAmount   = amountIn * fee / 1e6
protocolCut = feeAmount * protocolFeeBps / 1e4
netIn       = amountIn - feeAmount
amountOut   = netIn * reserveOut / (reserveIn + netIn)
reserveIn  += amountIn - protocolCut        // netIn + liquidity-provider fee
```

Pricing uses `netIn` against the pre-swap reserves, which is what makes the fee a real cost
to the trader. The liquidity-provider part of the fee raises `k`; the protocol cut is kept
out of the reserve so that `removeLiquidity` cannot pay it to providers.

## Pitfalls

- Checking `PoolExists` on the unsorted pair allows two pools for one pair and tier.
- Adding the full `amountIn` to the reserve and also crediting `protocolFees` counts the
  protocol cut twice; the last provider to exit or the fee collector then cannot be paid.
- Computing `removeLiquidity` from `balanceOf(pool)` instead of the reserves leaks protocol
  fees to providers.
- Leaving `FeePool.collectProtocolFees` open lets anyone drain the protocol balance.
- A zero-output swap must revert, otherwise dust inputs are donated silently.

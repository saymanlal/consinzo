# Fee Tier Factory Notes

## Why one pool per tier

A single fee cannot suit every pair. Stable pairs trade in volume at tight spreads and want
a low fee; volatile pairs need a higher fee to compensate providers. A factory that keys
pools by `(token0, token1, fee)` lets liquidity for each risk level live in its own pool
while guaranteeing there is exactly one canonical pool per key.

## Canonical ordering

A pair is unordered, but mapping keys are ordered. Sorting the two addresses once gives a
canonical `(token0, token1)` with `token0 < token1`. Every uniqueness check must be made on
the sorted pair.

## Fee bookkeeping

With fee `f` in millionths and protocol share `s` in basis points of the fee:

| Part | Formula | Destination |
| --- | --- | --- |
| net input | `amountIn - amountIn * f / 1e6` | priced, joins the reserve |
| provider fee | `feeAmount - protocolCut` | joins the reserve, raises `k` |
| protocol cut | `feeAmount * s / 1e4` | separate balance, collected via the factory |

Both divisions round down, so on very small swaps the protocol cut can be zero while the
fee is not. The accounting identity `balance == reserve + protocolFees` holds for each token
after every call.

## Square root for the first deposit

The first provider receives `sqrt(amount0 * amount1)` liquidity units, which makes the unit
independent of the ratio in which the pool was seeded. The Babylonian method converges from
above and returns the floor of the root.

# Consuming a Chainlink-style price feed safely

## What latestRoundData returns

| Field | Meaning |
| --- | --- |
| `roundId` | Identifier of the latest round |
| `answer` | Price as a signed integer with `decimals()` decimals |
| `startedAt` | Timestamp when the round started |
| `updatedAt` | Timestamp when the answer was written; `0` while the round is in progress |
| `answeredInRound` | Round in which `answer` was computed |

The function does not revert when data is old. Freshness is the consumer's responsibility.

## Checks a consumer should make

1. **Completeness**: `updatedAt != 0`.
2. **Round consistency**: `answeredInRound >= roundId`. Newer aggregator versions always
   return equal values, but the check is harmless and protects against older deployments.
3. **Freshness**: `block.timestamp - updatedAt <= heartbeat + margin`. Each feed publishes
   a heartbeat (maximum time between updates). Choose `maxStaleness` per feed.
4. **Sign**: `answer > 0`. The type is `int256`; never cast before checking.
5. **Circuit breaker**: some aggregators clamp answers to `[minAnswer, maxAnswer]`. If the
   reported price equals a limit, the true price is unknown. Rejecting such answers avoids
   lending against a price that no longer exists.

## Decimals

USD pairs usually use 8 decimals and ETH pairs 18. Read `decimals()` and scale to a single
internal precision. Do the scaling after validation.

## When the feed is unusable

Reverting pauses every action that depends on the price, which is the safe default for
borrowing and withdrawals. Design liquidation and repayment paths so that users can still
reduce risk while the oracle is down, and consider a secondary oracle for long outages.

# Patch a Price Feed Consumer That Trusts Stale and Incomplete Rounds

`CollateralValuer` prices collateral for a lending market. It reads a Chainlink-style
aggregator through `latestRoundData()` and converts the answer to an 18-decimal USD price.
`valueOf` and `maxBorrow` build on that price.

The contract uses only the `answer` field. It never looks at when the round was updated,
whether it was completed, or whether the answer is a real market price. If the feed stops
updating, the market keeps lending against an old price. A negative answer is cast to an
unsigned integer, which either overflows the scaling step or yields an absurd price. During a crash, a feed that has hit its configured floor keeps
reporting the floor.

## Your task

Patch `latestPrice()` in `src/CollateralValuer.sol`. It must validate the round and revert
with the errors below; when all checks pass it returns `answer` scaled to 18 decimals
exactly as it does today. `valueOf` and `maxBorrow` must revert whenever `latestPrice`
does.

Given `(roundId, answer, startedAt, updatedAt, answeredInRound) = feed.latestRoundData()`:

| Condition | Error |
| --- | --- |
| `updatedAt == 0` (round not finished) or `updatedAt > block.timestamp` | `IncompleteRound()` |
| `answeredInRound < roundId` (answer carried over from an older round) | `StaleRound()` |
| `block.timestamp - updatedAt > maxStaleness` | `StalePrice()` |
| `answer <= 0` | `InvalidPrice()` |
| `answer <= minAnswer` or `answer >= maxAnswer` | `PriceOutOfBounds()` |

Notes:

- A price that is exactly `maxStaleness` seconds old is accepted.
- `minAnswer` and `maxAnswer` are the feed's circuit-breaker limits, in feed decimals. An
  answer equal to a limit means the feed is clamping and is rejected; one unit inside the
  limit is accepted.
- Each test violates one condition at a time, so the order of your checks only has to be
  sensible, not identical to the table.
- Constructor parameters, immutables and the other functions must stay as they are.

## What the tests check

Public tests check scaling of a fresh price, a price older than the heartbeat, an
unfinished round and a negative answer. Hidden tests probe the exact staleness boundary,
carried-over rounds, zero and large negative answers, future timestamps, both circuit-breaker
limits and the values next to them, recovery after the feed updates, and an 18-decimal feed.

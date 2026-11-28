# Background: Consuming an Aggregator Price Feed

## The aggregator interface

A Chainlink-style aggregator exposes two calls that matter to a consumer:

- `decimals()` – how many decimals the answer carries;
- `latestRoundData()` – returns `(roundId, answer, startedAt, updatedAt, answeredInRound)`.

`answer` is signed because some feeds can legitimately be negative. A price consumer that
only makes sense for positive prices must reject zero and negative values itself.

## Fixed-point normalisation

A value `v` with `d` decimals represents the real number `v / 10**d`. To express the same
number with 18 decimals:

| feed decimals | operation                       |
| ------------- | ------------------------------- |
| `d < 18`      | `v * 10**(18 - d)` (exact)      |
| `d == 18`     | `v`                             |
| `d > 18`      | `v / 10**(d - 18)` (truncates)  |

Solidity 0.8 reverts on underflow, so `18 - d` cannot be evaluated when `d > 18`.

## Staleness

A feed keeps returning its last answer when updates stop. Consumers compare `updatedAt`
with `block.timestamp` and refuse answers older than a limit chosen for the feed's
heartbeat. `updatedAt == 0` indicates a round that has not been answered.

## Valuing an amount

For a base amount `a` with `b` decimals and a price `p` with 18 decimals, the value with 18
decimals is `a * p / 10**b`. Perform the multiplication first; integer division discards
the remainder.

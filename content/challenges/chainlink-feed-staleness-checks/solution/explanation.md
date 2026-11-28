# Reference Solution Explanation

## Root cause

`latestPrice` destructured `latestRoundData()` and kept only `answer`:

```solidity
(, int256 answer, , , ) = feed.latestRoundData();
return uint256(answer) * _scale;
```

Nothing tied the answer to the present. Four separate failure modes followed:

1. **Stale data.** A feed that stopped updating kept returning its last answer.
2. **Unfinished or carried-over rounds.** `updatedAt == 0` and `answeredInRound < roundId`
   both signal that the answer does not belong to a completed current round.
3. **Sign.** `uint256(int256(-1))` is `2**256 - 1`. A negative answer became an enormous
   price.
4. **Clamping.** Aggregators with `minAnswer`/`maxAnswer` report the limit when the market
   moves beyond it. Borrowing against a floor price during a collapse drains the market.

## Fix

`latestPrice` reads all relevant fields and checks them before converting:

- `updatedAt == 0 || updatedAt > block.timestamp` -> `IncompleteRound()`
- `answeredInRound < roundId` -> `StaleRound()`
- `block.timestamp - updatedAt > maxStaleness` -> `StalePrice()`
- `answer <= 0` -> `InvalidPrice()`
- `answer <= minAnswer || answer >= maxAnswer` -> `PriceOutOfBounds()`

The future-timestamp check comes before the subtraction so the age computation cannot
underflow into a panic. Because `valueOf` and `maxBorrow` call `latestPrice`, they inherit
every check.

## Pitfalls

- Using `>=` for the staleness comparison rejects a price that is exactly at the heartbeat.
- Checking bounds with strict inequalities (`<`, `>`) accepts the clamped value itself.
- Catching the revert and falling back to the last good price reintroduces the stale-price
  problem. A consumer should halt price-dependent actions instead.

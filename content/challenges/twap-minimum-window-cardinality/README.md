# Enforce a Minimum Window and Cardinality on a TWAP Oracle

`WindowedTwapOracle` reads a cumulative price from an AMM pair
(`currentCumulativePrice()` is the integral of the spot price over time, as in Uniswap V2).
The time-weighted average price between two moments is the difference of the cumulative
values divided by the elapsed time.

## The bug

The oracle stores one observation. `update()` is permissionless and overwrites it on every
call, and `consult()` averages from that observation to now. An attacker calls `update()`,
moves the spot price, holds it for a single block and calls a protocol that reads
`consult()`. The "time-weighted average" is then an average over twelve seconds and equals
the manipulated spot price.

## Your task

Patch `src/WindowedTwapOracle.sol`. Keep the interface unchanged.

```solidity
uint256 public constant MIN_WINDOW = 30 minutes;
uint256 public constant GRANULARITY = 5 minutes;
uint256 public constant CARDINALITY = 12;

constructor(address source_);                         // records the first observation
function update() external returns (bool recorded);
function consult() external view returns (uint256 price);
function observationCount() external view returns (uint256);   // total observations recorded
function latestObservation() external view returns (uint256 timestamp, uint256 cumulative);
```

### Required behaviour

- **Spacing.** `update()` records a new observation only if at least `GRANULARITY` seconds
  have passed since the latest recorded one. Otherwise it changes nothing and returns
  `false`. It never reverts.
- **Cardinality.** The oracle keeps the most recent `CARDINALITY` recorded observations in a
  ring buffer. Older ones may be overwritten.
- **Minimum window.** `consult()` selects the most recent stored observation that is at
  least `MIN_WINDOW` seconds old and returns
  `(source.currentCumulativePrice() - observation.cumulative) / (block.timestamp - observation.timestamp)`.
  If no stored observation is that old it reverts with `InsufficientHistory()`.

With these rules, moving the reported price requires holding the spot price away from its
true value for a meaningful part of thirty minutes, and nobody can erase the history in
one block.

## What the tests check

- After an hour of regular updates, a 100x spot move held for one block changes
  `consult()` by less than 2x (the starter reports about 100x).
- `consult()` reverts while history is shorter than `MIN_WINDOW`.
- Repeated `update()` calls cannot shorten the window or flush the buffer.
- Exact averages for sustained moves, sparse updates and after the ring wraps around.

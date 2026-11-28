# Price Feed Consumer with 18-Decimal Normalisation

## Problem Statement

Price oracles publish answers with their own number of decimals: USD pairs commonly use 8,
ETH-denominated pairs use 18, and nothing stops a feed from using more. A consumer that
forwards the raw answer forces every caller to know which feed it is talking to.

Implement `PriceFeedConsumer` in `src/PriceFeedConsumer.sol`. It wraps one aggregator that
follows the `IAggregatorV3` interface declared in the same file and exposes prices as
unsigned 18-decimal fixed-point numbers, rejecting answers that are unusable.

The aggregator used by the tests is a mock; nothing outside the package is called.

## Interface

```solidity
constructor(address feed_, uint256 maxAge_)

function feed() external view returns (IAggregatorV3);
function maxAge() external view returns (uint256);

function latestPrice() public view returns (uint256 price18);
function toQuote(uint256 baseAmount, uint8 baseDecimals) external view returns (uint256 quote18);

error ZeroAddress();
error InvalidPrice();
error StalePrice();
```

## Rules

1. The constructor reverts with `ZeroAddress()` when `feed_ == address(0)`. It stores the
   feed and `maxAge_` (seconds); both never change.
2. `latestPrice()` calls `feed.latestRoundData()` and `feed.decimals()` and returns the
   answer scaled to 18 decimals:
   - feed decimals below 18: multiply by `10 ** (18 - decimals)`;
   - feed decimals equal to 18: return the answer unchanged;
   - feed decimals above 18: divide by `10 ** (decimals - 18)`, rounding down.
3. `latestPrice()` reverts with `InvalidPrice()` when the answer is zero or negative.
4. `latestPrice()` reverts with `StalePrice()` when `updatedAt == 0`, when `updatedAt` is in
   the future, or when `block.timestamp - updatedAt > maxAge`. An answer that is exactly
   `maxAge` seconds old is still accepted. The answer check (rule 3) is applied first.
5. `toQuote(baseAmount, baseDecimals)` values an amount of the base asset, expressed with
   `baseDecimals` decimals, in the quote currency with 18 decimals:
   `baseAmount * latestPrice() / 10 ** baseDecimals`, rounding down. It reverts whenever
   `latestPrice()` reverts.

## What the tests check

- Scaling for feeds with fewer than, exactly and more than 18 decimals.
- Rejection of zero, negative, never-updated, future-dated and stale answers, and the exact
  boundary at `maxAge`.
- `toQuote` for base assets with 6, 8 and 18 decimals, including rounding.

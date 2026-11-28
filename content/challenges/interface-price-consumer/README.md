# Price Feed Interface, Provider and Consumer

## Problem Statement

`src/PriceConsumer.sol` declares the interface `IPriceFeed` and two contracts to implement:

- `FixedPriceFeed`, a provider whose owner sets the price by hand;
- `PriceConsumer`, which is given a provider at construction and reads from it through the
  interface.

The consumer must work with **any** contract that implements `IPriceFeed`, not only with
`FixedPriceFeed`.

## The Interface (given, do not change)

```solidity
interface IPriceFeed {
    function latestPrice() external view returns (uint256);
    function decimals() external view returns (uint8);
}
```

## FixedPriceFeed

```solidity
address public immutable owner;

error NotOwner();
error ZeroPrice();

constructor(uint256 initialPrice, uint8 decimals_);

function latestPrice() external view returns (uint256);
function decimals() external view returns (uint8);
function setPrice(uint256 newPrice) external;
```

1. The deployer becomes `owner`.
2. The constructor and `setPrice` revert with `ZeroPrice()` when the price is zero.
3. `setPrice` reverts with `NotOwner()` for any caller other than `owner`. This check runs first.
4. `latestPrice()` returns the most recently set price; `decimals()` returns the constructor
   argument.

## PriceConsumer

```solidity
IPriceFeed public immutable feed;

error ZeroFeed();

constructor(IPriceFeed feed_);

function currentPrice() external view returns (uint256);
function quote(uint256 amount) external view returns (uint256);
function isAtLeast(uint256 threshold) external view returns (bool);
```

1. The constructor reverts with `ZeroFeed()` when `feed_` is the zero address.
2. `currentPrice()` returns `feed.latestPrice()` as it is at the time of the call.
3. `quote(amount)` returns `amount * price / 10 ** decimals`, rounded down, where `price` and
   `decimals` are read from the feed at the time of the call.
4. `isAtLeast(threshold)` returns `true` when the current price is greater than or equal to
   `threshold`.
5. The consumer never stores a price. A change in the provider is visible in the very next call.

## What the Tests Check

- The provider's access control, zero-price checks and stored values.
- The consumer's three views against `FixedPriceFeed`.
- The consumer against a different `IPriceFeed` implementation defined in the tests, with other
  decimals and a price that changes between calls.

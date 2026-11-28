# Interfaces and Calls Between Contracts

## What an interface is

An interface is a list of external function signatures without bodies. It cannot declare state
variables or a constructor. Its purpose is to describe how to talk to a contract whose source
you may not have:

```solidity
interface IPriceFeed {
    function latestPrice() external view returns (uint256);
    function decimals() external view returns (uint8);
}
```

A contract states that it conforms with `contract X is IPriceFeed`. The compiler then refuses to
compile `X` unless every function of the interface is implemented.

## Calling through an interface

```solidity
IPriceFeed feed = IPriceFeed(someAddress);
uint256 p = feed.latestPrice();
```

The cast does not check anything at run time; it only tells the compiler which selectors exist.
The call itself reverts if the target has no code, reverts if the callee reverts, and reverts if
the returned data cannot be decoded as the declared return type. Calls to `view` functions use
`STATICCALL`, so the callee cannot modify state.

## Dependency injection

Passing the provider to the constructor, rather than creating it inside the consumer, lets the
same consumer code be deployed against a live oracle, a fixed test value or a mock. Validate the
address in the constructor, because an `immutable` reference cannot be repaired afterwards.

## Fixed-point prices

Prices are integers scaled by `10 ** decimals`. A feed with 8 decimals reports 2,000.5 as
`200_050_000_000`. To value an amount, compute `amount * price / 10 ** decimals` and decide
deliberately which way the division should round.

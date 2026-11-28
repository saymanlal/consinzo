# Reference Solution Explanation

## The interface is the contract between the two sides

`IPriceFeed` lists two external view functions and nothing else. `FixedPriceFeed is IPriceFeed`
tells the compiler to check that both are implemented with matching signatures.
`PriceConsumer` holds a value of type `IPriceFeed`; when it calls `feed.latestPrice()` the compiler
encodes the selector and arguments, performs a `STATICCALL` to the stored address and decodes the
result. The consumer has no knowledge of how the provider computes its answer, which is why the
hidden tests can substitute providers of their own.

## Provider

- `owner` is `immutable` and set to `msg.sender` in the constructor.
- The price lives in storage because it changes; the decimals never change, so they are
  `immutable` as well.
- `setPrice` checks the caller before it checks the value. A stranger who passes zero is told
  `NotOwner()`, not `ZeroPrice()`.

## Consumer

- `feed` is `immutable`: the provider is chosen once, at construction, and a zero address is
  rejected there.
- All three views call the provider on every invocation. Storing the price in the constructor
  would freeze it at its deployment value and fail every test that updates the provider.
- `quote` multiplies before dividing by `10 ** decimals`. The exponent is widened to `uint256`
  first so that the power is computed in 256 bits rather than in `uint8`.

## Pitfalls

- Typing the consumer's field as `FixedPriceFeed`. It still compiles and passes the public tests,
  but it couples the consumer to one implementation for no benefit.
- Computing `10 ** feed.decimals()` in `uint8`, which overflows for three or more decimals.
- Using `>` instead of `>=` in `isAtLeast`.

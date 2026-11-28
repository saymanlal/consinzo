# Reference Solution Explanation

## Structure

`fill` is written as checks, authorisation, effects, interactions.

1. **Checks.** Order sanity, expiry, taker restriction and the nonce bit are evaluated before
   any hashing-dependent state is read. The fill is bounded by `takerAmount - filled`, so the
   sum of all fills of one digest can never exceed the quoted size.
2. **Price.** `makerFillAmount = takerFillAmount * makerAmount / takerAmount` rounds down.
   Summed over any sequence of partial fills the maker gives at most `makerAmount`, and a
   fill so small that the maker side rounds to zero is rejected instead of taking the
   taker's tokens for nothing.
3. **Authorisation.** The digest is the EIP-712 hash, so it commits to every field, the chain
   id and this contract's address. An empty signature selects the pre-approval mapping. A
   maker with code is asked through ERC-1271 inside `try/catch`, so a reverting wallet is an
   invalid signature rather than an unexplained revert. For an EOA the signature must be 65
   bytes, `s` must be in the lower half of the curve order and `v` must be 27 or 28; this
   removes the malleable twin `(r, n - s, v ^ 1)`. A zero address from `ecrecover` is
   rejected explicitly, which matters when `order.maker` is `address(0)`.
4. **Effects.** The filled amount is written and, when the order is complete, the nonce bit
   is set.
5. **Interactions.** `_pull` performs a low-level `transferFrom`, accepts empty return data
   and requires `true` otherwise.

## Why the nonce bit is set only on completion

Fill progress lives under the order digest, cancellation under the maker's nonce. Setting the
bit on the first partial fill would make the rest of the order unfillable. Setting it on
completion keeps replay protection (a completed order has no remaining amount and a used
nonce) and gives makers one-cancels-the-other quotes: several orders sharing a nonce die
together when one completes or when the maker invalidates the nonce.

## Pitfalls

- Hashing with `abi.encodePacked` or omitting a field lets a taker change that field.
- Leaving out `address(this)` or the chain id allows replay on another deployment.
- Accepting high-`s` signatures is harmless for replay here (state is keyed by digest), but
  it is still a second valid encoding of the same authorisation and is rejected by the spec.
- Updating `filledTakerAmount` after the transfers lets a malicious token re-enter `fill`
  while the order still looks unfilled and drain the maker's allowance.
- Treating a `false` return from `transferFrom` as success settles one leg only.
- Letting anyone call `preApprove` for an arbitrary maker is a complete authorisation bypass.

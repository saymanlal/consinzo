# RFQ Settlement Notes

## Request for quote

In an RFQ flow a taker asks market makers for a price, a maker answers with a firm quote and
the taker (or a solver acting for it) settles the quote on-chain. The maker pays no gas and
takes no on-chain action for quotes that are never used. The settlement contract is the only
component that must be trusted, and its job is narrow: prove that the maker agreed to exactly
these terms, and exchange the two tokens atomically.

## Typed data digests

EIP-712 defines `digest = keccak256(0x1901 || domainSeparator || hashStruct(message))`.
`hashStruct` is `keccak256(abi.encode(typeHash, fields...))`, with each field padded to 32
bytes. The domain separator binds a signature to one contract on one chain. Because every
field is inside the hash, changing any of them produces a different digest and the original
signature no longer recovers the maker.

## Three ways to authorise

- **ECDSA.** `ecrecover(digest, v, r, s)` returns the signer or `address(0)` on failure. For
  every valid `(r, s, v)` there is a second valid signature `(r, n - s, v ^ 1)`; restricting
  `s` to the lower half of the curve order leaves exactly one.
- **ERC-1271.** Contract accounts have no private key. They expose
  `isValidSignature(bytes32, bytes)` and return the magic value `0x1626ba7e` when they accept.
- **Pre-approval.** The maker sends a transaction that records the digest. This costs gas but
  needs no signature scheme at all and works for any account type.

## Nonce bitmaps

A sequential nonce forces orders to be used in sequence. A bitmap gives each maker 256
independent nonces per storage slot: nonce `n` is bit `n & 0xff` of word `n >> 8`. Cancelling
a batch of quotes is a single storage write, and orders can be filled in any order.

## Partial fills and rounding

Progress is tracked per digest in taker-token units. The maker side of each fill is computed
with integer division and rounds down, so repeated small fills can never extract more than
the quote allows. The complementary risk, a fill whose maker side rounds to zero, is rejected.

## Token calls

`transferFrom` implementations differ: some revert on failure, some return `false`, and some
return nothing. A settlement contract should use a low-level call and treat "call succeeded
and returned either nothing or `true`" as success. All state changes belong before the first
external call.

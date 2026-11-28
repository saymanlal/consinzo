# ecrecover and the zero address

## What the precompile does

`ecrecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) returns (address)` recovers the
address whose private key produced the ECDSA signature `(v, r, s)` over `hash`. On failure
it returns `address(0)`. It never reverts. Failure cases include:

- `v` not equal to 27 or 28;
- `r` or `s` equal to zero, or not smaller than the secp256k1 group order;
- `r` not corresponding to a valid curve point.

## Why zero is dangerous

`address(0)` is also the default value of every unset `address` storage slot, mapping entry
and struct field. Code of the form

```solidity
require(ecrecover(h, v, r, s) == storedAddress);
```

is therefore satisfied by a garbage signature whenever `storedAddress` was never written,
was deleted, or was deliberately reset. Typical places: an owner that was renounced, a
signer that is configured after deployment, `ownerOf(tokenId)` for a token that does not
exist, a mapping lookup for an unknown key.

## Rules for signature checks

1. Reject `recovered == address(0)` explicitly.
2. Make sure the expected signer is a real, non-zero address before comparing.
3. Bind the signed message to its context: contract address, chain id, recipient, amount
   and a nonce or deadline.
4. Prevent replay with nonces or by marking the message hash as used.
5. If replay protection depends on the signature bytes, also require `s` in the lower half
   of the curve order (EIP-2).

## Pausing a signature-gated function

Represent "paused" with an explicit check that fails closed. Reusing the zero value of the
signer as the pause switch only works if the verification code refuses to run in that
state.

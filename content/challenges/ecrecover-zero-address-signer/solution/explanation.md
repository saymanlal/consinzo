# Reference Solution Explanation

## Root cause

```solidity
address recovered = ecrecover(digest, v, r, s);
if (recovered != signer) revert InvalidSignature();
```

The precompile returns `address(0)` for inputs it cannot recover (a `v` other than 27 or
28, `r` or `s` equal to zero or not below the curve order, or a point that does not exist).
The contract used `address(0)` as its own "no signer" marker: the slot is zero after
deployment and after `clearSigner()`. In those states `recovered == signer` holds for any
garbage signature, with attacker-chosen `amount` and `nonce`.

## Fix

Three independent changes, each sufficient against the exploit in the tests and each
closing a different way of getting back to the bad state:

1. `redeem` reverts with `SignerNotSet()` while `signer == address(0)`. A paused contract
   verifies nothing.
2. `redeem` treats `recovered == address(0)` as `InvalidSignature()`. The comparison can no
   longer succeed by coincidence of two "empty" values.
3. `setSigner` rejects `address(0)` with `ZeroSigner()`, so the empty state is only entered
   deliberately through `clearSigner()`.

The nonce check stays first so that a used voucher always reports `VoucherUsed()`.

## Notes and pitfalls

- Checking only `v == 27 || v == 28` is not enough; `r = 0` with a valid `v` also recovers
  to zero.
- This contract tracks nonces, so signature malleability (the high-`s` twin of a valid
  signature) cannot be used for a second payout. A contract that keys replay protection on
  the signature bytes would also need a low-`s` check.
- The digest includes `block.chainid` and `address(this)`, which prevents reuse of vouchers
  on another chain or another deployment.

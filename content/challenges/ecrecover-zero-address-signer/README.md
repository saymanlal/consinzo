# Patch a Voucher Contract That Accepts ecrecover's Zero Address

`VoucherRedeemer` holds ETH and pays out vouchers. A voucher is a signature by the
configured `signer` over `voucherDigest(to, amount, nonce)`; the recipient calls
`redeem(amount, nonce, v, r, s)` and each nonce can be used once.

The signer is not known at deployment. The owner sets it later with `setSigner`, and can
pause redemptions with `clearSigner`, which stores `address(0)`.

`redeem` computes `ecrecover(digest, v, r, s)` and compares the result with `signer`.
`ecrecover` does not revert on a malformed signature; it returns `address(0)`. Whenever the
signer slot is empty, a call such as `redeem(balance, anyNonce, 0, 0, 0)` recovers
`address(0)`, the comparison succeeds and the contract pays. "Paused" is the most dangerous
state the contract can be in.

## Your task

Patch `src/VoucherRedeemer.sol`. Keep signatures, events, errors and `voucherDigest`
unchanged (the tests use vouchers that were signed off-chain for the existing digest).

## Required behaviour

`redeem(uint256 amount, uint256 nonce, uint8 v, bytes32 r, bytes32 s)` checks, in this
order:

1. `VoucherUsed()` if `usedNonce[nonce]`;
2. `SignerNotSet()` if `signer == address(0)`;
3. `InvalidSignature()` if `ecrecover` returns `address(0)` or any address other than
   `signer`;

then marks the nonce used and sends `amount` wei to `msg.sender` (`TransferFailed()` if the
transfer fails). A voucher is bound to its recipient, amount, nonce, chain id and this
contract's address through the digest.

Signer management:

- `setSigner(address)` is owner-only and reverts with `ZeroSigner()` for `address(0)`.
- `clearSigner()` is owner-only and is the only way to return to the "no signer" state.
  While no signer is set, every redemption reverts, including ones with a signature that
  was valid before the pause. After `setSigner` is called again, valid vouchers work.
- Non-owners get `NotOwner()`.

## About the test fixtures

The harness has no `vm.sign`. The tests therefore contain three signatures produced
off-chain by a fixed test key for the redeemer address that results from deploying it first
in `setUp()` on chain id 1. You do not need to generate signatures to solve the mission.

## What the tests check

Public tests redeem a valid voucher, replay it, and submit an unrecoverable signature both
before a signer was ever set and after it was cleared. Hidden tests try a matrix of
malformed `(v, r, s)` values in all three signer states, check `ZeroSigner()` and
`SignerNotSet()`, pause and resume, binding of vouchers to recipient, amount and nonce,
signer rotation and access control.

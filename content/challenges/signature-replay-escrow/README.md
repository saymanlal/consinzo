# Fix Signature Replay Vulnerability in Payment Escrow

`SignedEscrow` lets a signer authorize ETH payouts via `ecrecover`, but currently ignores `nonce` and `address(this)`, allowing identical signatures to be replayed until the contract is drained.

## Objective
1. Include `address(this)`, `block.chainid`, `recipient`, `amount`, and `nonce` in `computeDigest`.
2. Enforce `nonce == nonces[signer]` and increment `nonces[signer]` before transferring ETH.
3. Reject `ecrecover(...) == address(0)` or `signer != expectedSigner`.

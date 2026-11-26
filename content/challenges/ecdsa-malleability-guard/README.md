# Prevent ECDSA Signature Malleability Replay

Tracking `usedSig[keccak256(abi.encodePacked(v, r, s))]` allows an attacker to flip `v` and compute `s' = secp256k1n - s` to bypass replay checks.

## Objective
1. Track `usedDigest[digest]` instead of raw `(v,r,s)`.
2. Enforce EIP-2 lower-S bound: `uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0` and `v == 27 || v == 28`.
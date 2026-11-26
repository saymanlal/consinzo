# Prevent ECDSA Signature Malleability Replay

Keys replay state on `digest` and enforces EIP-2 lower-S (`s <= secp256k1n / 2`) and `v in {27, 28}`.

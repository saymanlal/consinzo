# Signature Replay Protection Reference
Always bind off-chain authorization signatures to chain ID, verifying contract address, and single-use nonces, and reject `address(0)` from `ecrecover`.

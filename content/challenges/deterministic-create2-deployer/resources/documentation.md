# Deterministic CREATE2 Factory & Address Predictor

Applies EIP-1014 `keccak256(0xff ++ deployer ++ salt ++ keccak256(initCode))` prediction and verifies `addr != address(0)` after `create2`.

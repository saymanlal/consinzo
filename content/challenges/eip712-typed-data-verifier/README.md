# EIP-712 Typed Data Verifier

Implement `DOMAIN_SEPARATOR()`, `hashOrder(address maker, uint256 amount, uint256 nonce)`, and `computeTypedDigest(bytes32 structHash)` following `\x19\x01 || domainSeparator || structHash`.
# Reference Solution Explanation
Includes `block.chainid` and `address(this)` in the hashed payload, checks `recovered != address(0)`, enforces `nonce == nonces[expectedSigner]`, and increments the nonce prior to ETH transfer.

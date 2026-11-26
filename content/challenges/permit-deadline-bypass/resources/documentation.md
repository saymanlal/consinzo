# Enforce Permit Deadline & Nonce Invariants

Validates non-zero `owner`/`spender`, enforces `block.timestamp <= deadline`, and increments `nonces[owner]`.

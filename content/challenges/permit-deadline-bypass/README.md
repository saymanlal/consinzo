# Enforce Permit Deadline & Nonce Invariants

`PermitVault.permit` skips `block.timestamp <= deadline` and `nonces[owner]++`.

## Objective
Reject expired deadlines (`block.timestamp > deadline`) and increment `nonces[owner]` on valid consumption.
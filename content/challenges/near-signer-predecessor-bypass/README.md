# Patch NEAR Signer vs Predecessor Confused-Deputy Vault

## Vulnerability Summary
`SignerVault.ts` currently authenticates callers using `near.signerAccountId()` instead of `near.predecessorAccountId()`. If a victim calls any malicious dApp or proxy contract, that relay inherits the victim's `signerAccountId()` and can call `withdraw()` or `setPaused()` on the victim's behalf.

## Remediation Requirements
1. Authenticate `deposit()`, `withdraw(amount)`, and `setPaused(paused)` strictly with `near.predecessorAccountId()`.
2. Reject zero-deposit calls, non-positive withdrawal amounts, and withdrawals exceeding the caller's balance.
3. Enforce pause protection on `withdraw()` when `paused === true`.

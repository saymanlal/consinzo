# Patch NEAR Cross-Contract Callback Double-Refund Vulnerability

## Vulnerability Summary
Because NEAR cross-contract calls are asynchronous, contracts deduct balances before dispatching an external transfer and rely on a callback (`onTransferCallback(txId, succeeded)`) to credit back funds if the remote call failed.

`AsyncRouter.ts` currently has two critical flaws:
1. Anyone can invoke `onTransferCallback()` externally because it fails to check `near.predecessorAccountId() === near.currentAccountId()`.
2. Pending transfer entries remain `"PENDING"` after failure refunding, allowing repeated failure callbacks to mint arbitrary refunds.

## Remediation Requirements
1. Restrict `onTransferCallback(txId, succeeded)` strictly to `near.predecessorAccountId() === near.currentAccountId()`.
2. Enforce single-resolution transitions (`"PENDING"` -> `"SETTLED"` or `"REFUNDED"`), reverting on duplicate callback invocations.
3. Credit the user's balance on `succeeded === false` ONLY after marking the pending record `"REFUNDED"`.

# Fix Dual-Control Guards That Accept a Single Role

`DualControlTreasury` holds ETH for an organisation that works under dual control. Two roles
exist, `TREASURER_ROLE` and `COMPLIANCE_ROLE`, and the owner assigns them with `setRole`.
Sensitive actions are supposed to need an officer who holds **both** roles, so that a single
compromised key cannot move money.

Several guards in the contract combine the two role checks with the wrong boolean operator.
As deployed, an account holding only one of the roles can pay itself, lift an emergency pause
and raise the payment limit.

## Your task

Patch `src/DualControlTreasury.sol` so every function enforces exactly the policy below. Do
not change function signatures, errors or events.

| Function | Who may call it |
| --- | --- |
| `setRole(bytes32 role, address account, bool enabled)` | owner only (`NotOwner()` otherwise) |
| `executePayment(address payable to, uint256 amount)` | an account holding **both** roles |
| `pause()` | an account holding **either** role |
| `unpause()` | an account holding **both** roles |
| `setPaymentLimit(uint256 newLimit)` | the owner, **or** an account holding both roles |

Callers that do not satisfy the policy must revert with `Unauthorized()`.

## Rules

- The owner is an administrator, not an officer. Without both roles the owner cannot call
  `executePayment`, `pause` or `unpause`.
- The authorisation check comes first. An unauthorised caller gets `Unauthorized()` even if
  another check would also fail.
- The remaining checks are unchanged: `executePayment` reverts with `TreasuryPaused()` while
  paused, `ZeroAddress()` for a zero recipient and `OverLimit()` when
  `amount > paymentLimit`; `unpause` reverts with `NotPaused()` when the treasury is not
  paused.
- Revoking either role from an officer immediately removes their dual-control rights.

## What the tests check

Public tests confirm that an officer with both roles can pay, that a treasurer-only account
cannot, that either role can pause and that a single role cannot unpause. Hidden tests walk
through the remaining combinations of caller and function, including the owner, a stranger,
revoked roles and the payment-limit guard.

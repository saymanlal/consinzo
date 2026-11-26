# Solution Explanation: NEAR Async Callback Guard

1. **Private Callback Enforcement**: Enforces `near.predecessorAccountId() === near.currentAccountId()` so arbitrary callers cannot forge promise results.
2. **Idempotent Resolution State**: Requires `tx.status === "PENDING"` and transitions to `"SETTLED"` or `"REFUNDED"` before crediting the failed transfer amount back to the user's balance.

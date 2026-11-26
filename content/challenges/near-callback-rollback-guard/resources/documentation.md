# NEAR Asynchronous Callback Invariants

- Always check `near.predecessorAccountId() === near.currentAccountId()` on `@private` / internal promise callbacks.
- Lock or settle in-flight withdrawal records before returning failed funds so neither concurrent transfers nor replayed callbacks can inflate balances.

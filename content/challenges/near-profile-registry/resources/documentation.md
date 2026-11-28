# Background: per-account records on NEAR

- `near.predecessorAccountId()` is the account that directly called the contract. It is the correct identity for authorisation. `near.signerAccountId()` is the account that signed the original transaction and can differ when another contract makes the call.
- `LookupMap<V>` provides `get` (returns `null` when missing), `set`, `containsKey` and `remove`. It stores nothing about its size, so contracts that need a count must maintain one.
- Storing a record under the caller's own account id is the simplest access-control scheme: there is nothing to check, because the caller can only ever address its own key.
- `near.blockTimestamp()` returns nanoseconds since the Unix epoch as a `bigint`.

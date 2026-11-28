# Background: append-only logs on NEAR

- A NEAR contract keeps its state in a key-value store. `LookupMap<V>` wraps that store with a key prefix and supports `get`, `set`, `containsKey` and `remove`. It does not know how many keys it holds and cannot be iterated.
- To model a list, store a counter in the contract and use the stringified index as the map key. Reading a range is then a loop over indices.
- `near.predecessorAccountId()` returns the account that made the current call. `near.blockTimestamp()` returns the block time in nanoseconds as a `bigint`.
- View methods that return many items should always be bounded by a caller-supplied count, because the cost of a call grows with the amount of state it reads.

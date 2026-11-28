# Background: bounded user input

- Every byte a contract stores is paid for from the contract's balance (storage staking). User-supplied strings should always have a maximum length so one caller cannot make the contract store arbitrarily large values.
- Validate inputs at the top of a method, before any state is modified. In a real NEAR runtime a panic reverts the state changes of the call, but writing checks first also keeps the logic easy to reason about.
- `LookupMap.remove` deletes a key. After removal `get` returns `null` and `containsKey` returns `false`.
- Counters that describe history should be stored separately from the current value they describe, so that clearing the value does not erase the history.

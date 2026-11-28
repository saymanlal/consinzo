# Background: receiving NEAR in a contract call

- A call to a NEAR contract can carry a deposit. Inside the contract `near.attachedDeposit()` returns it as a `bigint` in yoctoNEAR (1 NEAR = 10^24 yoctoNEAR).
- JavaScript `number` cannot represent such values exactly. Always keep balances as `bigint` and write literals with the `n` suffix.
- A `LookupMap` is a keyed store without iteration or size. Aggregates such as totals, counts and maxima must be updated in the same call that changes the underlying entries.
- An aggregate that can be updated incrementally (a sum, a count, a maximum over values that only grow) costs constant work per call, which keeps gas use predictable.

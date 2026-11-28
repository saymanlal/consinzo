# Solution Explanation: NEAR Donation Ledger

1. **The amount is the attached deposit.** `donate()` takes no arguments. Reading `near.attachedDeposit()` means the recorded amount always equals the tokens that actually arrived with the call.
2. **Unique donors.** `LookupMap.get` returns `null` for an account that never donated, which is the signal to increment the donor count. Using `0n` as the signal would also work here only because zero donations are rejected.
3. **Top donor without iteration.** A `LookupMap` cannot be scanned for a maximum. Because totals only ever grow, the maximum can be maintained incrementally: after each donation, compare the donor's new cumulative total with the stored top total.
4. **Tie rule.** The comparison is strict (`>`), so an account that equals the top total does not displace the leader.
5. **bigint arithmetic.** yoctoNEAR amounts exceed `Number.MAX_SAFE_INTEGER`; all sums use `bigint`.

## Pitfalls
- Comparing the single deposit instead of the cumulative total with the top total.
- Using `>=`, which hands the lead to whoever reached the total last.
- Counting donations instead of distinct donors.

# Solution Explanation: NEAR Minimal Non-Fungible Token

1. **Token ownership map.** `owners` maps a token id to its owner. A token exists exactly when its id is a key in that map, which gives uniqueness (`mint` requires the key to be absent) and the `Token not found` check for free.
2. **Per-token authorisation.** `transfer` loads the stored owner and compares it with `near.predecessorAccountId()`. The minter role only controls creation; it gives no power over existing tokens. After a transfer the previous owner fails the same check.
3. **Balances as a derived index.** `balances` is maintained on every mint and transfer so `balanceOf` is a single lookup. Mint adds one to the receiver and to the supply; transfer subtracts one from the old owner and adds one to the new owner, leaving the supply unchanged.
4. **Self-transfer rejected.** Besides being pointless, a self-transfer is the case where "read both balances, then write both" style code corrupts the balance. Rejecting it removes that hazard.
5. **Check order.** The documented order puts authorisation ahead of argument validation, so callers without rights always receive the authorisation error.

## Pitfalls
- Letting the minter (or any account) transfer tokens it does not own.
- Updating `owners` but forgetting one of the two balance updates.
- Allowing a token id to be minted again after it was transferred.

# Solution Explanation: NEAR Minimal Fungible Token

1. **Sender is the predecessor.** `transfer` and `burn` take the source account from `near.predecessorAccountId()`, never from an argument, so a caller can only move its own tokens.
2. **Check order.** The four `transfer` checks run in the documented order: receiver present, not a self-transfer, positive amount, sufficient balance. Each failure has its own message, and nothing is written until all four pass.
3. **Positive amounts only.** `amount > 0n` is a security check, not a courtesy. With signed `bigint` arithmetic, a negative amount would pass `balance >= amount` and then *increase* the sender's balance while decreasing the receiver's.
4. **Conservation.** A transfer writes `sender - amount` and `receiver + amount`. Rejecting self-transfers removes the classic bug where both writes use a stale balance and the second overwrites the first. Only `burn` changes `supply`, and it changes the caller's balance by the same amount.

## Pitfalls
- Reading the receiver's balance before writing the sender's and then writing both when sender and receiver are the same account.
- Using `number` for amounts.
- Forgetting to reduce the total supply in `burn`.

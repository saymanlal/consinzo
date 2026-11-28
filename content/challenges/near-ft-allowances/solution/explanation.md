# Solution Explanation: NEAR Fungible Token Allowances

1. **Pair-keyed storage.** An allowance is identified by (owner, spender). The composite key `owner + ":" + spender` is unambiguous because `:` cannot appear in a NEAR account id.
2. **Roles in `transferFrom`.** The caller is the spender. The allowance consulted is the one the *owner* granted to the *caller*; the receiver plays no part in authorisation. Looking up `(caller, owner)` or `(owner, receiver)` instead is the most common mistake.
3. **Checks before effects.** Receiver, amount, allowance and balance are validated in that order, and only then are the three writes performed. A failed call therefore leaves the allowance untouched.
4. **Overwrite semantics for `approve`.** Setting rather than adding makes revocation (`approve(spender, 0n)`) possible and keeps the meaning of the call independent of history.
5. **`receiver === owner`.** The debit is written before the receiver's balance is read, so the credit starts from the already reduced balance and the two cancel exactly. Reading both balances first and writing both afterwards would mint or destroy tokens in this case.

## Pitfalls
- Decreasing the allowance but not checking it, or checking it against the wrong pair.
- Positive-amount check missing: a negative `amount` passes both `>=` comparisons and reverses the transfer.
- Reducing the allowance on a path that later fails the balance check.

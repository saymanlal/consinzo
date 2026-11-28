# Solution Explanation: Unprotected Fee Configuration

## Root cause
`setFeeConfig` wrote `feeRecipient` and `feeBps` for any caller. Every public method of a NEAR contract can be called by any account, so a method that changes privileged state without comparing the caller to an authorised account is open to everyone.

## Impact
- Redirecting the recipient steals all future protocol fees.
- Setting `feeBps` to `10000` sends the whole payment to the attacker; a value above `10000` makes `amount - fee` negative and corrupts the merchant ledger.

## Fix
```ts
assert(near.predecessorAccountId() === this.owner, "Not owner");
assert(recipient.length > 0 && feeBps >= 0n && feeBps <= MAX_FEE_BPS, "Invalid fee config");
```

Both checks run before either field is written, so a rejected call cannot leave a half-applied configuration.

### Why predecessor
`signerAccountId()` is the account that signed the transaction and is unchanged across cross-contract calls. If the router authorised the signer, any contract the owner ever calls could forward a call to `setFeeConfig` and pass the check. `predecessorAccountId()` is the direct caller.

### Why validate owner input
Access control limits who can call; validation limits what a call can do. The fee cap protects merchants from a compromised owner key and from a typo such as `2500` instead of `250`. The same bound is already applied in the constructor, so the configuration invariant `feeBps <= MAX_FEE_BPS` now holds for the whole lifetime of the contract.

## Accounting
`pay` credits the recipient configured at the time of the payment. The patch does not move existing balances, so the old recipient can still withdraw what it earned.

# Patch an Unprotected Fee Configuration Method on NEAR

## Scenario
`FeeRouter` forwards payments to merchants and keeps a protocol fee. `pay(merchant)` splits the attached deposit: `amount * feeBps / 10000` is credited to the fee recipient, the rest to the merchant. Balances are an internal ledger collected with `withdraw()`.

The fee recipient and the fee rate can be changed after deployment with `setFeeConfig(recipient, feeBps)`.

## Vulnerability
`setFeeConfig` in `src/FeeRouter.ts` performs no authorisation and no validation. Any account can

- replace the fee recipient with itself and collect all future protocol fees, or
- raise the fee to 100% (or more) and take the merchants' revenue.

## Your task
Patch `src/FeeRouter.ts` without changing the public interface.

1. `setFeeConfig(recipient, feeBps)` must throw `"Not owner"` unless `near.predecessorAccountId()` is the owner. Authenticate the predecessor, not the transaction signer.
2. It must throw `"Invalid fee config"` if `recipient` is empty or `feeBps` is outside `0n..MAX_FEE_BPS` (`MAX_FEE_BPS = 1000n`, i.e. 10%).
3. A rejected call must leave the configuration unchanged.
4. Fees credited before a configuration change stay with the previous recipient.
5. `transferOwnership(newOwner)` must keep working for the owner; after a transfer the previous owner has no privileges.

## Interface (unchanged)

```ts
constructor(feeRecipient: string, feeBps: bigint)   // owner = near.predecessorAccountId()
pay(merchant: string): bigint                        // returns the fee taken
setFeeConfig(recipient: string, feeBps: bigint): void
transferOwnership(newOwner: string): void
withdraw(): bigint
getOwner(): string
getFeeRecipient(): string
getFeeBps(): bigint
balanceOf(account: string): bigint
```

## What the tests check
The public tests run the takeover and expect it to be rejected. The hidden tests cover the fee bound, calls routed through an intermediary contract, ownership transfer and the accounting across a legitimate configuration change.

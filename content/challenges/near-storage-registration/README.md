# NEAR Storage Registration with Refunds

## Objective
Implement `RegisteredNotes` in `src/RegisteredNotes.ts`. Storing data on NEAR costs the contract money, so this contract asks each account to pay a storage fee before it may store a note. The pattern follows the idea of NEP-145 storage management.

Outgoing NEAR is modelled as a per-account **refundable balance** that the account collects with `claimRefund()`.

## Interface

```ts
constructor(storageFee: bigint)        // owner = near.predecessorAccountId()
register(): void                       // fee paid with near.attachedDeposit()
unregister(): bigint                   // returns the refunded storage fee
setNote(text: string): void
getNote(account: string): string | null
claimRefund(): bigint                  // returns the amount paid out
setStorageFee(newFee: bigint): void
isRegistered(account: string): boolean
storageBalanceOf(account: string): bigint
refundableOf(account: string): bigint
getStorageFee(): bigint
totalStorageHeld(): bigint
```

## Rules
1. The constructor requires `storageFee > 0n`, otherwise it throws an error containing `Invalid fee`.
2. `register()`:
   - If the caller is already registered, throw an error containing `Already registered`.
   - The attached deposit must be at least the current storage fee, otherwise throw an error containing `Insufficient storage deposit`.
   - The caller's storage balance is set to the **current fee**. Any excess (`deposit - fee`) is added to the caller's refundable balance.
3. `setNote(text)`: the caller must be registered, otherwise throw an error containing `Not registered`. `text` must be 1 to 200 characters, otherwise throw `Invalid note`. Stores or replaces the caller's note.
4. `unregister()`: the caller must be registered (`Not registered`). It deletes the caller's note and registration, adds the caller's recorded storage balance to its refundable balance and returns that amount.
5. `claimRefund()`: pays out the caller's whole refundable balance, sets it to `0n` and returns the amount. If the balance is `0n`, throw an error containing `Nothing to refund`. Registration is not required to claim.
6. `setStorageFee(newFee)`: owner only (`Only owner`), `newFee > 0n` (`Invalid fee`). It applies to future registrations only. Accounts that are already registered keep their recorded storage balance and are refunded that recorded amount.
7. `storageBalanceOf(account)` is the fee recorded for a registered account and `0n` otherwise. `totalStorageHeld()` is the sum of the storage balances of all currently registered accounts.

## What the tests check
The registration gate, exact-fee and over-payment handling, refund amounts after a fee change, data deletion on unregister, re-registration, claiming, and that totals stay consistent.

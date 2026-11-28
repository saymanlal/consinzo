# NEAR Fungible Token Allowances

## Objective
Implement `AllowanceToken` in `src/AllowanceToken.ts`. The basic `transfer` and balance views are already provided in the starter. Add the allowance mechanism: `approve`, `allowance` and `transferFrom`.

## Interface

```ts
constructor(initialSupply: bigint)                 // minted to the deployer (provided)
transfer(receiver: string, amount: bigint): void   // provided
balanceOf(account: string): bigint                 // provided
totalSupply(): bigint                              // provided

approve(spender: string, amount: bigint): void
allowance(owner: string, spender: string): bigint
transferFrom(owner: string, receiver: string, amount: bigint): void
```

## Rules
1. `approve(spender, amount)` sets how many tokens `spender` may move out of the caller's balance.
   - `spender` must be non-empty and different from the caller, otherwise throw an error containing `Invalid spender`.
   - `amount` must be `>= 0n`, otherwise throw an error containing `Negative allowance`.
   - The new value **replaces** the old one. `approve(spender, 0n)` revokes the allowance.
   - The caller does not need to hold the approved amount at the time of approval.
2. `allowance(owner, spender)` returns the remaining allowance (`0n` if none was set).
3. `transferFrom(owner, receiver, amount)` is called by the spender and moves `amount` from `owner` to `receiver`. Checks, in order:
   1. `receiver` is empty: `Invalid receiver`
   2. `amount <= 0n`: `Amount must be positive`
   3. `allowance(owner, caller) < amount`: `Insufficient allowance`
   4. `balanceOf(owner) < amount`: `Insufficient balance`

   On success the owner's balance and the allowance each decrease by `amount`, and the receiver's balance increases by `amount`.
4. `transferFrom` with `receiver === owner` is allowed: balances are unchanged but the allowance is still consumed.
5. Allowances are per (owner, spender) pair and are independent of each other. A direct `transfer` by the owner does not change any allowance.
6. `totalSupply()` never changes.

## What the tests check
Allowance bookkeeping, spending in several steps, spending to a third account, isolation between spenders and between owners, overwrite and revoke semantics, the order of the failure checks, and that a failed `transferFrom` leaves the allowance intact.

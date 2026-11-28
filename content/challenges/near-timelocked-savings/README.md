# NEAR Time-Locked Savings Box

## Objective
Implement `SavingsBox` in `src/SavingsBox.ts`. Every account has at most one savings box holding an amount and an unlock time. Funds can be withdrawn only when the block timestamp has reached the unlock time.

## Interface

```ts
deposit(unlockAt: bigint): bigint   // amount = near.attachedDeposit(); returns the box balance
withdraw(): bigint                  // returns the amount paid out
balanceOf(account: string): bigint
unlockTimeOf(account: string): bigint   // 0n when the account has no box
isUnlocked(account: string): boolean
totalLocked(): bigint
```

All times are nanosecond timestamps compared with `near.blockTimestamp()`.

## Rules
1. `deposit(unlockAt)`:
   - The attached deposit must be greater than `0n`, otherwise throw an error containing `Deposit required`.
   - If the caller has **no** box, `unlockAt` must be strictly greater than the current block timestamp, otherwise throw an error containing `Unlock time must be in the future`. A new box is created with the deposit and that unlock time.
   - If the caller **already has** a box, the deposit is added to it. `unlockAt` must be greater than or equal to the box's current unlock time, otherwise throw an error containing `Cannot shorten lock`. The box's unlock time becomes `unlockAt`. This applies even if the existing box has already unlocked.
   - Returns the box balance after the deposit.
2. `withdraw()`:
   - If the caller has no box, throw an error containing `Nothing to withdraw`.
   - If `near.blockTimestamp() < unlockAt`, throw an error containing `Still locked`.
   - Otherwise the whole balance is paid out: the box is deleted and the amount is returned. A later deposit starts a fresh box.
3. `balanceOf` and `unlockTimeOf` return `0n` for accounts without a box.
4. `isUnlocked(account)` is `true` only when the account has a box and the current block timestamp is at or past its unlock time.
5. `totalLocked()` is the sum of all box balances.

## What the tests check
Locking and withdrawing at the exact boundary, top-ups, extending and attempting to shorten the lock, isolation between accounts, re-use after withdrawal and the total.

# NEAR Pausable Ledger with Admin and Pauser Roles

## Objective
Implement `PausableLedger` in `src/PausableLedger.ts`. Accounts deposit and withdraw balances. The contract has an emergency stop controlled by two roles.

## Roles
- **admin**: the account that constructs the contract. Can pause, unpause, appoint the pauser and hand over the admin role.
- **pauser**: one optional account appointed by the admin. Can pause, but cannot unpause.

## Interface

```ts
constructor()                         // admin = near.predecessorAccountId(), no pauser, not paused
setPauser(account: string): void      // "" removes the pauser
transferAdmin(newAdmin: string): void
pause(): void
unpause(): void
deposit(): bigint                     // amount = near.attachedDeposit(); returns the new balance
withdraw(amount: bigint): bigint      // returns the remaining balance
balanceOf(account: string): bigint
isPaused(): boolean
getAdmin(): string
getPauser(): string                   // "" when no pauser is set
```

## Rules
1. `setPauser(account)`: admin only, otherwise throw an error containing `Only admin`. Passing `""` removes the pauser.
2. `transferAdmin(newAdmin)`: admin only (`Only admin`); `newAdmin` must be non-empty (`Invalid admin`). The previous admin loses its rights.
3. `pause()`: the caller must be the admin or the current pauser, otherwise throw an error containing `Not authorized`. If the contract is already paused throw `Already paused`.
4. `unpause()`: admin only (`Only admin`). If the contract is not paused throw `Not paused`.
5. `deposit()`: throws `Contract is paused` while paused. The attached deposit must be greater than `0n`, otherwise throw `Deposit required`. Adds the deposit to the caller's balance.
6. `withdraw(amount)`: works whether or not the contract is paused. `amount <= 0n` gives `Amount must be positive`; an amount above the caller's balance gives `Insufficient balance`.
7. Role checks come before state checks: an unauthorised caller always gets the role error.
8. An account with no pauser set (`""`) must never match: a caller is the pauser only if a pauser is set and equals the caller.

## What the tests check
Who can pause and unpause, deposits blocked and withdrawals allowed while paused, replacing and removing the pauser, admin handover, and the order of role and state checks.

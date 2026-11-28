# NEAR Minimal Fungible Token

## Objective
Implement `SimpleToken` in `src/SimpleToken.ts`: the core accounting of a fungible token in the spirit of NEP-141 (`ft_transfer`, `ft_balance_of`, `ft_total_supply`), with a burn function. Amounts are `bigint`.

## Interface

```ts
constructor(initialSupply: bigint)   // minted to near.predecessorAccountId()
transfer(receiver: string, amount: bigint): void
burn(amount: bigint): void
balanceOf(account: string): bigint
totalSupply(): bigint
```

## Rules
1. The constructor requires `initialSupply > 0n`, otherwise it throws an error containing `Invalid supply`. The whole supply is credited to the account that constructs the contract.
2. `transfer(receiver, amount)` moves tokens from `near.predecessorAccountId()` to `receiver`. The checks run in this order, each with its own error:
   1. `receiver` is empty: `Invalid receiver`
   2. `receiver` equals the caller: `Cannot transfer to self`
   3. `amount <= 0n`: `Amount must be positive`
   4. the caller's balance is less than `amount`: `Insufficient balance`
3. `burn(amount)` destroys tokens of the caller: `amount <= 0n` gives `Amount must be positive`, a balance below `amount` gives `Insufficient balance`. Burning reduces both the caller's balance and the total supply.
4. `balanceOf(account)` returns `0n` for unknown accounts.
5. Invariant: `totalSupply()` always equals the sum of all balances. Transfers never change it.
6. A rejected call must not change any state.

## What the tests check
Balance movement, the exact error for every failure and their order, transferring an entire balance, supply conservation over a sequence of transfers, and burn accounting.

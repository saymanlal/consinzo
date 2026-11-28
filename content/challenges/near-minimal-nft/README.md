# NEAR Minimal Non-Fungible Token

## Objective
Implement `SimpleNft` in `src/SimpleNft.ts`: the ownership core of an NFT contract in the spirit of NEP-171. Token ids are strings chosen at mint time.

## Interface

```ts
constructor()                                   // minter = near.predecessorAccountId()
mint(tokenId: string, receiver: string): void
transfer(tokenId: string, receiver: string): void
ownerOf(tokenId: string): string | null
balanceOf(account: string): number
totalSupply(): number
getMinter(): string
```

## Rules
1. The account that constructs the contract is the minter.
2. `mint(tokenId, receiver)` creates a token owned by `receiver`. Checks, in order:
   1. caller is not the minter: `Only minter`
   2. `tokenId` is empty: `Invalid token id`
   3. `receiver` is empty: `Invalid receiver`
   4. the token id already exists: `Token already exists`
3. `transfer(tokenId, receiver)` moves a token to `receiver`. Checks, in order:
   1. the token does not exist: `Token not found`
   2. caller is not the current owner of that token: `Not token owner`
   3. `receiver` is empty: `Invalid receiver`
   4. `receiver` is the current owner: `Cannot transfer to self`
4. `ownerOf(tokenId)` returns the current owner or `null` for an unknown token.
5. `balanceOf(account)` returns how many tokens the account currently owns.
6. `totalSupply()` returns the number of minted tokens. Transfers do not change it.
7. Invariant: the sum of all balances equals `totalSupply()`.

## What the tests check
Minting rights, uniqueness of token ids, ownership after transfers, that a previous owner and the minter cannot move tokens they do not own, balance bookkeeping and the order of the checks.

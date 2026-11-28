# NEAR Commit-Reveal Lottery with No-Reveal Penalty

## Objective
Implement `CommitRevealLottery` in `src/CommitRevealLottery.ts`. Block data on NEAR can be influenced by validators, so this lottery derives its randomness from the players: each player first commits to a hash of a secret seed and later reveals the seed. The winner is selected from the XOR of all revealed seeds.

A player who sees that the outcome is bad for them could simply not reveal. To make that costly, every player posts a bond with the ticket. The bond is returned on reveal and forfeited to the pot otherwise.

Payouts are modelled as an internal ledger (`balanceOf`) with a pull `withdraw`.

## Provided helper
`hashCommitment(account, seed, salt)` is already implemented in the starter. It is a 64-bit FNV-1a hash and stands in for `sha256`, which the test runtime does not provide. Do not change it; the tests import it.

## Interface

```ts
constructor(ticketPrice: bigint, bond: bigint, commitEndNs: bigint, revealEndNs: bigint)
commit(commitment: string): void
reveal(seed: bigint, salt: string): void
finalize(): string
withdraw(): bigint
getWinner(): string
isFinalized(): boolean
hasRevealed(account: string): boolean
playerCount(): number
revealCount(): number
balanceOf(account: string): bigint
```

## Rules
1. Constructor: throws `"Invalid config"` unless `ticketPrice > 0n`, `bond > 0n`, `commitEndNs > near.blockTimestamp()` and `revealEndNs > commitEndNs`.
2. `commit(commitment)`, with `now = near.blockTimestamp()`:
   - `"Commit phase over"` if `now >= commitEndNs`;
   - `"Invalid commitment"` if the string is empty;
   - `"Wrong deposit"` unless `near.attachedDeposit() === ticketPrice + bond`;
   - `"Already committed"` if the caller committed before.
3. `reveal(seed, salt)`:
   - `"Not in reveal phase"` unless `commitEndNs <= now < revealEndNs`;
   - `"No commitment"` if the caller never committed; `"Already revealed"` on a second reveal;
   - `"Invalid seed"` if `seed < 0n`;
   - `"Commitment mismatch"` unless `hashCommitment(caller, seed, salt)` equals the stored commitment.
   - On success the caller's bond is credited to their balance and the seed is XOR-ed into the combined seed. Revealers are remembered in the order in which they revealed.
4. `finalize()`: callable by anyone.
   - `"Reveal phase not over"` if `now < revealEndNs`; `"Already finalized"` on a second call.
   - If at least one player revealed: the winner is `revealers[combinedSeed % revealers.length]`. The winner is credited the pot: `ticketPrice * playerCount + bond * (playerCount - revealCount)`.
   - If nobody revealed there is no winner: every player is credited `ticketPrice + bond` and the result is the empty string.
   - Returns the winner's account id (or `""`), which `getWinner()` returns from then on. Before finalization `getWinner()` returns `""`.
5. `withdraw()` returns the caller's balance and sets it to zero. Throws `"Nothing to withdraw"` when the balance is zero.

## What the tests check
Phase boundaries, deposit checks, commitments that cannot be copied or altered, the exact winner and pot for given seeds, forfeited bonds, the no-reveal refund path, and that the sum of all credited balances equals the sum of all deposits.

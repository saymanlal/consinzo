# NEAR Weighted DAO Proposal & Quorum Engine

## Objective
Implement `DaoVoting` in `src/DaoVoting.ts` supporting weighted members, single-vote-per-proposal enforcement, and deterministic quorum finalization.

## Specification
1. Constructor `new DaoVoting(quorumWeight: bigint)`:
   - Sets `owner = near.predecessorAccountId()`, requires `quorumWeight > 0n`.
2. `setMemberWeight(account: string, weight: bigint): void`:
   - Owner-only (`near.predecessorAccountId() === owner`).
   - Requires non-empty `account` and `weight >= 0n`.
3. `createProposal(description: string, durationNs: bigint): number`:
   - Requires caller's weight `> 0n`, non-empty `description`, and `durationNs > 0n`.
   - Assigns sequential `proposalId` starting at `1`, sets `deadline = near.blockTimestamp() + durationNs`, initializes `yesWeight = 0n`, `noWeight = 0n`, `finalized = false`, `passed = false`.
4. `vote(proposalId: number, support: boolean): void`:
   - Require valid proposal, `!finalized`, `near.blockTimestamp() <= deadline`, voter weight `> 0n`, and voter has not previously voted on `proposalId`.
   - Add voter's weight to `yesWeight` or `noWeight` and record vote receipt.
5. `finalize(proposalId: number): boolean`:
   - Require valid proposal, `!finalized`, and `near.blockTimestamp() > deadline`.
   - Set `finalized = true`, `passed = yesWeight >= quorumWeight && yesWeight > noWeight`, and return `passed`.
6. View helpers: `getProposal(proposalId)`, `getMemberWeight(account)`.

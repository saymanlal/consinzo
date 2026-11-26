# Solution Explanation: NEAR Weighted DAO Voting

1. **Governance Access Control**: `setMemberWeight` is gated to `this.owner` via `near.predecessorAccountId()`, and non-members (`weight === 0n`) cannot create proposals or cast votes.
2. **Double-Vote Defense**: Composite key `${proposalId}:${voter}` in `LookupMap` guarantees one vote per account per proposal.
3. **Strict Finalization**: Requires `near.blockTimestamp() > p.deadline` and passes only when both quorum (`yesWeight >= quorumWeight`) and strict majority (`yesWeight > noWeight`) hold.

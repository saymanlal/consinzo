# Block Flash-Loan Governance Vote Hijacking

`SnapshotDAO.vote` checks `token.balanceOf(msg.sender)`, letting an attacker flash-borrow tokens, pass a proposal, and repay in the same block.

## Objective
Require users to stake/lock governance power via `lockVotes(amount)` and only accept votes whose `lockedAtBlock[msg.sender] < proposalStartBlock[id]`.
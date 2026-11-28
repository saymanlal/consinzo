# Randomness and commit-reveal on NEAR

## Why not block data
`near.blockTimestamp()` and the block random seed are known to (and to some degree chosen by) the validator that produces the block, and they are visible to every contract call in that block. A lottery that derives its winner from them can be predicted or biased.

## Commit-reveal
1. **Commit.** Each participant publishes `H(account, seed, salt)`. The hash hides the seed and fixes it.
2. **Reveal.** After commitments close, each participant publishes `seed` and `salt`. The contract recomputes the hash and accepts the seed only if it matches.
3. **Combine.** The accepted seeds are combined (here with XOR). A single honest participant is enough for the result to be unpredictable at commit time.

Including the account id in the hash prevents replaying somebody else's commitment. The salt adds entropy so that small seeds cannot be found by trying all values.

## The last-revealer problem
Whoever reveals last can compute the result before deciding whether to reveal. Commit-reveal alone does not solve this. The usual mitigation is economic: a deposit that is lost when a committed participant does not reveal.

## Hash function in this challenge
The test runtime has no `sha256`. The starter ships a 64-bit FNV-1a hash as a stand-in. It is not collision resistant enough for real funds; on chain you would use `near.sha256` and compare byte arrays.

## Pull payments
Winnings are credited to an internal balance and collected with `withdraw`. This avoids a failing transfer blocking `finalize`.

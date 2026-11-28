# Background: Checkpoints, Quorums and Rotation

## Checkpoints

Instead of proving every cross-chain message separately, a bridge can commit to a batch.
All pending withdrawals are put into a Merkle tree and only the 32-byte root crosses the
bridge. Anyone holding a leaf and its sibling path can later prove membership.

## Byzantine quorums

With `n` validators of which fewer than one third may misbehave, a decision needs strictly
more than `2n/3` votes. Any two such quorums share more than `n/3` validators, so at least
one honest validator is in both, and honest validators do not vote for conflicting values.
"At least two thirds" is not enough: with `n = 3`, two votes would be accepted, and two
quorums of two can share a single, possibly dishonest, validator.

The argument also needs each validator to vote **once** per decision.

## Rotation

The validator set changes: stake moves, operators leave. The outgoing set authorises its
successor with the same quorum rule. Two things must hold across the hand-over:

- validators that left have no remaining influence, including through votes they cast
  before leaving;
- an authorisation given for one hand-over cannot be replayed for another.

Tagging every vote with the set's epoch, and including the target epoch in what is voted
on, achieves both.

## Positional Merkle proofs

In a positional tree, the leaf at index `i` is combined with its sibling on the right when
`i` is even and on the left when `i` is odd; then `i` is halved and the process repeats.
The verifier must check that the index fits the depth of the proof. A separate concern is
that inner nodes and leaves must be hashed differently so that one cannot stand in for the
other.

## Exactly-once exits

A withdrawal needs an identifier that is independent of the checkpoint it is proven
against, because overlapping or cumulative checkpoints may contain the same withdrawal
more than once.

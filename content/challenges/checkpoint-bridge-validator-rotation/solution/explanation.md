# Reference Solution Explanation

## Epoch-scoped attestations

Every tally is stored under the epoch in which the votes were cast:

```
_rootVotes[epoch][checkpointId][root]
_votedCheckpoint[epoch][checkpointId][validator]
_rotationVotes[epoch][proposal]
```

A rotation only increments `epoch`. That single write invalidates every pending tally,
without iterating over anything. It is the core of the problem: if tallies were global, a
set that is about to be replaced could leave a malicious root one vote short, and a single
member of the new set (or a member common to both) could complete it. With epoch keys the
new set starts from zero and reaches its own quorum.

Membership is stored the same way (`_inSet[epoch][validator]`), so installing a set never
has to delete the old one.

Accepted roots are *not* epoch-scoped. Once a root is final, later rotations do not affect
withdrawals against it.

## Quorum

`count * 2 / 3 + 1` is the smallest integer strictly greater than `2/3 * count`. The common
mistake `(count * 2 + 2) / 3` gives "at least two thirds": 2 of 3, or 4 of 6. Two quorums of
that size can overlap in only one third of the set, which is exactly the fraction that is
allowed to be dishonest, so two conflicting roots could both be accepted.

## One vote per checkpoint

The voter flag is keyed by checkpoint id, not by `(id, root)`. A validator that could vote
for two roots of the same checkpoint would count towards two conflicting quorums.

## Rotation proposals

The proposal hash commits to `epoch + 1` and the new set. Combined with epoch-scoped
tallies this means a proposal can only ever be completed by the set that started voting on
it. Requiring strictly ascending addresses makes validation O(n), makes the hash canonical
(one encoding per set) and excludes the zero address for free.

## Merkle proofs

The tree is positional: the index bits decide whether the running hash is the left or the
right input at each level. After consuming the proof the remaining index must be zero;
otherwise index `5` would verify with the proof for index `1` in a two-level tree.

Leaves are hashed twice. A leaf pre-image is 96 bytes and an inner-node pre-image is 64
bytes, and with the second hash a leaf is `keccak(32 bytes)`, so no inner node can be
re-interpreted as a leaf.

## Withdrawals

Replay protection is keyed by the withdrawal nonce alone. Keying by `(checkpoint, index)`
would pay a withdrawal again whenever it appears in a later checkpoint. The nonce is marked
before the ETH is sent, so a re-entrant recipient hits `AlreadyWithdrawn()`, and a failed
send reverts the mark together with everything else.

## Pitfalls

- Global vote counters that survive rotation.
- Checking membership against the current set but counting votes cast by a previous one.
- Voter flag per root instead of per checkpoint.
- Ignoring left-over index bits in the proof.
- Replay protection keyed by checkpoint.

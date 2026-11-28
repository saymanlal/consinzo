# Reference Solution Explanation

## Structure

A poll is four numbers: a topic, a deadline and two counters. Membership is a mapping filled in by
the constructor, and `hasVoted[pollId][member]` prevents a second vote.

The outcome is never stored. It is a pure function of the counters and the current time, which
removes the need for a "finalize" transaction: once `block.timestamp >= deadline`, no vote can be
added, so the result computed by `outcome` can no longer change.

## The two conditions

1. **Quorum**: `yesVotes + noVotes >= quorum`. A "no" vote counts towards quorum. This matters:
   staying away and voting no are different actions with different effects.
2. **Threshold**: `yesVotes * 10000 >= thresholdBps * (yesVotes + noVotes)`.

The threshold is cross-multiplied. The tempting form `yesVotes * 10000 / total >= thresholdBps`
rounds the left side down and so can only err towards rejecting, but the equally tempting
`yesVotes >= total * thresholdBps / 10000` rounds the right side down and lets a poll pass with
too few yes votes (for example 1 of 3 votes at 3334 bps).

## Pitfalls

- **Deadline boundary.** Voting is open while `block.timestamp < deadline`; from `deadline` on the
  poll is final. Using `<=` in one place and `<` in the other would create an instant where a poll
  reports a final outcome and still accepts a vote.
- **Unknown poll ids.** An unwritten `Poll` has deadline `0`, so without the `pollId >= pollCount`
  check an unknown poll would look like a finished poll with no votes.
- **Per-poll vote tracking.** `hasVoted` must be keyed by poll id first; a single
  `mapping(address => bool)` would let each member vote in only one poll ever.

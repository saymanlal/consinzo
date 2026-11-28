# Quorum and Threshold Voting: Background

## Membership voting

Not every DAO weighs votes by token balance. Committees, multisig-like councils and
proof-of-personhood communities use one member, one vote. The contract then needs a membership
set and a per-poll record of who has voted.

## Quorum

A quorum is the minimum participation for a decision to be valid at all. It protects against a
small group deciding while everyone else is away. Design choices to be aware of:

- What counts towards quorum. Here every cast vote counts, yes or no. Some systems count only yes
  votes (plus abstentions), which makes voting no risky for opponents because it helps reach
  quorum.
- Absolute or relative. Here quorum is an absolute number of votes, checked in the constructor to
  be at most the number of members.

## Passing threshold

The threshold is the share of cast votes that must be in favour. 5001 bps means a strict majority
for small electorates, 6667 bps is a two-thirds supermajority (rounded up), 10000 bps is unanimity
among those who voted.

Integer arithmetic has no fractions, so compare shares by cross-multiplying:

```
yes / total >= t / 10000    <=>    yes * 10000 >= t * total
```

## Deadlines without a finalize step

If nothing can change after the deadline, the outcome can be computed on demand in a view function
instead of being written by a transaction. This saves gas and removes a whole class of "who calls
finalize" problems.

# Reference Solution Explanation

## State machine

```
None --post--> Pending --challenge--> Challenged --resolve(true)--> None (claim deleted)
                  |                        |
                  |                        +--resolve(false)--> Upheld --finalize--> Finalized
                  +--finalize after period-------------------------------------> Finalized
```

Every function starts by checking the status it requires, so each transition can happen
only once. `Finalized` is terminal and keeps the slot occupied for ever, which is what
prevents a second payout for the same source message.

## Three pools of ETH

The contract balance is the sum of deposited liquidity, bonds locked in live claims, and
credits waiting to be withdrawn. Only `liquidity` may pay messages. `finalize` therefore
compares `amount` with the `liquidity` variable rather than with `address(this).balance`;
the latter would let a large claim be paid with other relayers' bonds, leaving them unable
to recover their money.

## Bonds

The bond is stored in the claim at posting time and the challenger must match that stored
value. If `challenge` used the current `bondAmount`, raising the setting would make old
claims more expensive to dispute than they are to post, and lowering it would let a
challenger win a larger bond than they risked. Storing it also makes the slash amount
exact: `2 * claim.bond`.

When a challenge fails, the relayer is credited the challenger's bond immediately, but its
own bond remains locked until `finalize`. Paying both at resolution would require
`finalize` to remember that the bond has already left.

## Windows

`challenge` requires `timestamp < postedAt + period` and `finalize` requires
`timestamp >= postedAt + period`. The two conditions are complementary, so there is no
instant at which a claim can be both challenged and finalized, and none at which it can be
neither.

A `Challenged` claim is excluded from `finalize` regardless of time. Without that, a
relayer could post a false claim, wait out the clock while the dispute is open, and
finalize before the arbiter answers.

## Payments

All payouts are credits collected through `withdraw`, which zeroes the credit before the
external call. A recipient contract that reverts or re-enters affects only its own
withdrawal.

## Pitfalls

- Checking `address(this).balance` in `finalize`.
- Leaving a rejected claim in place, which either blocks the slot for the honest message
  or leaves stale `challenger` data for the next claim.
- Forgetting to release the relayer's bond on finalization, or releasing it twice after an
  upheld challenge.
- Off-by-one at the end of the window.

# Reference Solution Explanation

## Structure

The campaign is a small state machine driven by two facts: whether `block.timestamp` has reached
`deadline`, and whether `totalRaised` reached `goal`. No explicit state variable is needed because
both facts are fixed once the deadline has passed (contributions stop at the deadline, and
`totalRaised` is never decreased).

- `contribute` is open strictly before the deadline (`block.timestamp < deadline`).
- `claim` and `refund` are open from the deadline onwards and are mutually exclusive:
  `claim` needs `totalRaised >= goal`, `refund` needs `totalRaised < goal`.

## Why `totalRaised` is not reduced on refund

If refunds reduced `totalRaised`, nothing would break in this design, but keeping it constant is
what makes the outcome immutable after the deadline. It is also what lets `claim` pay out
`totalRaised` rather than `address(this).balance`, so ETH force-sent to the contract cannot change
any decision.

## Pitfalls

- **Off-by-one at the deadline.** The deadline instant belongs to the "ended" phase: contributing
  at `deadline` reverts, claiming or refunding at `deadline` works.
- **Checks-effects-interactions.** `refund` zeroes `contributions[msg.sender]` before the call, and
  `claim` sets `claimed` before the call. A re-entrant `refund` then reverts with
  `NothingToRefund()`.
- **`transfer` and `send`.** They forward only 2300 gas and fail for many contract wallets. The
  reference uses `call` and checks the returned flag.
- **Pull over push.** The contract never loops over backers. Each backer withdraws their own
  refund, so one backer that rejects ETH cannot block the others.

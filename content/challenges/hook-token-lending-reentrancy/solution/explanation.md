# Reference Solution Explanation

## Root cause

```solidity
uint256 remaining = balance - amount;
...
collateralToken.transfer(msg.sender, amount);   // recipient hook runs here
collateralOf[msg.sender] = remaining;           // stale value written afterwards
```

During the transfer, `collateralOf[msg.sender]` still held the full balance. A nested
`withdrawCollateral(amount)` passed every check and transferred again; both frames then
wrote the same `remaining`, so two payouts were booked as one. Solidity's checked arithmetic
does not help because the code assigns a cached value instead of subtracting in storage.
`borrow` read the same stale balance, so the hook could also take a loan sized for
collateral that had already left.

## Fix

1. **Checks-effects-interactions in `withdrawCollateral`.** `collateralOf` and
   `totalCollateral` are updated before the transfer. A nested withdrawal now sees the
   reduced balance, and a nested borrow is limited by it.
2. **A shared `nonReentrant` lock on all four state-changing functions.** The hook can reach
   any entry point, so guarding only the function that makes the call would leave
   cross-function paths open if the code changes later. Deposits are locked as well because
   a hook-enabled token may also call the sender.

Either measure stops the two attacks in this challenge; together they do not depend on each
function being ordered perfectly forever.

## Pitfalls

- Guarding only `withdrawCollateral` leaves `borrow` reachable from the hook. It happens to
  be safe once the ordering is fixed, but only because of the ordering.
- Replacing the assignment by `collateralOf[msg.sender] -= amount` after the transfer turns
  the double withdrawal into a revert, yet the borrow-in-hook path still works.
- Rejecting contract callers does not help: hooks can be registered for any address through
  registries such as ERC-1820.

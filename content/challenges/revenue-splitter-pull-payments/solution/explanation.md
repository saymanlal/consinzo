# Reference Solution Explanation

## Approach

The splitter never stores per-deposit information. It relies on one identity:

```
totalReceived = address(this).balance + totalReleased
```

Every wei that ever entered the contract is either still there or was released. A payee's
cumulative entitlement is `totalReceived * shares / totalShares`, and what it may withdraw now
is that entitlement minus `released[account]`. The formula gives the same result for any
interleaving of deposits and releases, which is why the order of calls does not matter.

`release` follows checks-effects-interactions: it writes `released` and `totalReleased` and
only then sends the ETH. The EVM moves the value before the recipient's code runs, so if the
recipient re-enters `release` during the transfer it sees a balance that is already reduced and
a `totalReleased` that is already increased. `totalReceived` is therefore unchanged, the
recipient's `released` already includes the payment in flight, and `releasable` is zero: the
re-entrant call reverts with `NothingDue()`. Had the storage writes come after the send, the
re-entrant call would compute the same non-zero amount again and drain the other payees.

The invariants `sum(released) == totalReleased` and `released[a] <= entitlement(a)` hold after
every call and at every point where control leaves the contract.

## Pull over push

Because every payee is paid in its own call, a payee whose `receive` reverts only makes its own
`release` revert (`TransferFailed`). A push-style loop over all payees would let that payee
freeze everyone's funds.

## Pitfalls

- Using `address(this).balance * shares / totalShares` pays later claimers from a smaller pot.
- Sending before updating `released` allows a plain re-entrancy drain.
- Detecting duplicates needs no second loop: a non-zero `shares[account]` during construction
  means the address was already added.
- Integer division leaves at most `payeeCount - 1` wei of dust in the contract. It is not lost:
  it is included in the next computation because entitlements are cumulative.

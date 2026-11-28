# Payment Splitting and Pull Payments

## Push versus pull

A contract that owes money to several parties can either send it to them (push) or let them
collect it (pull). Pushing in a loop couples every recipient to every other one: if a single
transfer fails, the whole transaction reverts. The Solidity documentation recommends the
withdrawal (pull) pattern for this reason. Each recipient's payment happens in a separate
call, so failures are isolated.

## Cumulative accounting

For a pot that keeps receiving funds, compute entitlements from the cumulative amount received,
not from the current balance:

```
entitlement(account) = totalReceived * shares[account] / totalShares
payable now          = entitlement(account) - released[account]
```

`totalReceived` does not need its own storage slot. It equals the current balance plus the sum
of all releases.

## Sending ETH

`recipient.call{value: amount}("")` forwards all remaining gas and returns a success flag that
must be checked. Because the recipient gains control during the call, state must be updated
before it (checks-effects-interactions).

## Rounding

Integer division truncates. Each payee can be short by less than one wei at any time, so the
contract may hold a few wei that are not yet assignable. They are distributed automatically as
more revenue arrives.

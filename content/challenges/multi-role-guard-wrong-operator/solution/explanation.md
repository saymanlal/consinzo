# Reference Solution Explanation

## Root cause

Each guard was written in negated form (`if (<not allowed>) revert`). Negating "holds A and
holds B" gives "lacks A **or** lacks B", but three guards used `&&`, which is the negation of
"holds A or holds B". The result:

| Function | Intended | Starter accepted |
| --- | --- | --- |
| `executePayment` | both roles | either role |
| `unpause` | both roles | either role (written as `!(A || B)`) |
| `setPaymentLimit` | owner, or both roles | owner, or either role |
| `pause` | either role | either role (correct) |

A treasurer-only key could therefore raise the limit and pay out the whole balance.

## Fix

The reference introduces two positive predicates, `_hasBoth` and `_hasEither`, and writes
every guard as `if (!predicate(msg.sender)) revert Unauthorized();`. The compound condition is
stated once, in its natural form, and never negated by hand. `setPaymentLimit` becomes
`msg.sender != owner && !_hasBoth(msg.sender)`.

`pause` keeps the weaker check on purpose: stopping the treasury should be possible for one
officer, restarting it should not.

## Pitfalls

- Replacing every `&&` with `||` breaks `pause`, which then rejects single-role officers.
- In `setPaymentLimit` the owner alternative is joined with `&&` in the negated form. Writing
  `msg.sender != owner || !_hasBoth(...)` would lock out the owner unless they also hold both
  roles.
- Authorisation must stay the first check so that unauthorised callers learn nothing about
  the paused state or the limit from the revert reason.

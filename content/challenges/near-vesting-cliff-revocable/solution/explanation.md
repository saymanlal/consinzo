# Solution Explanation: Revocable Vesting Grants

## Vesting curve
`vested()` has three branches. The cliff check is written as `now < startNs + cliffNs`, which also covers `now < startNs`; without it `now - startNs` would be negative and a bigint division would produce a negative vested amount. Inside the linear range the multiplication happens first (`total * elapsed / durationNs`), so precision is only lost in the final rounding step and the last release at the end timestamp picks up all accumulated dust because the end branch returns `total` exactly.

## Release
`released` is a counter on the grant. `release` pays `vested - released` and updates the counter before crediting, so two calls in the same block cannot pay twice and the sum of all releases equals the vested amount.

## Revocation
The vested amount is computed once, the unvested remainder is credited to the grantor, and the grant's `total` is replaced by the vested amount with `revoked = true`. From then on `vested()` returns `total`, which freezes the schedule without storing a separate timestamp. Because `released <= vested` held before the revoke, `releasable` stays non-negative and the beneficiary can still collect what was vested but unpaid.

## Pitfalls
- Dividing before multiplying (`total / durationNs * elapsed`) loses up to `durationNs - 1` units per grant.
- Recomputing the refund from the original total after a revoke would allow a second revoke to pay again; the `revoked` flag blocks it.
- Checking `near.signerAccountId()` instead of the predecessor would let an intermediary contract release or revoke on behalf of the user.

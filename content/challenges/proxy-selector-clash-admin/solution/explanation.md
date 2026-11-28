# Why the patch works

## What went wrong

The EVM identifies a function by the first four bytes of the hash of its signature. Solidity
compiles a contract into a dispatcher that compares the incoming selector with the selectors
of its own external functions and only runs `fallback()` if none match. For a proxy this
means: every external function declared on the proxy hides any implementation function with
the same selector, for every caller.

`collate_propagate_storage(bytes16)` and `burn(uint256)` both hash to `0x42966c68`. The proxy
function overwrote the admin slot with `msg.sender`, so `burn(0)` promoted any caller to
admin. From there `upgradeTo` and a sweeping implementation drain the contract.

Deleting that one function is not a complete fix. The remaining proxy functions still shadow
the implementation, and the next clash would again be invisible in a code review.

## The transparent proxy pattern

The reference declares no external functions at all. `fallback()` and `receive()` call
`_route()`, which looks only at the caller:

- not the admin: `delegatecall` to the implementation, always;
- the admin: decode `msg.sig` by hand and serve `admin()`, `implementation()`,
  `upgradeTo(address)` and `changeAdmin(address)`; revert with `AdminCannotFallback()` for
  anything else.

Users and the admin now live in separate call spaces. A user call can never land on admin
logic regardless of its selector, and the admin can never accidentally run implementation
code with admin privileges of the proxy.

## Pitfalls

- Keeping `upgradeTo` as a declared function with an `onlyAdmin` modifier is safe against
  takeover but still shadows the implementation; the clashing-implementation test fails.
- Forwarding the admin's unknown calls to the implementation re-opens selector confusion in
  the other direction. Revert instead.
- Admin answers must be returned with an assembly `return`, since `fallback()` has no return
  type in this form.
- `receive()` must route too, otherwise plain ETH from users never reaches the token.

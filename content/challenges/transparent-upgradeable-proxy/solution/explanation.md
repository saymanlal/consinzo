# Reference Solution Explanation

## Storage

The proxy declares no state variables. The implementation and admin addresses are read and
written with `sload` / `sstore` at the two EIP-1967 slots. Those slots are hashes minus
one, so no Solidity mapping or array of the implementation can land on them.

## Dispatch

Everything goes through `fallback()`:

1. If `msg.sender` is not the admin, `_delegate` copies the calldata, performs the
   `delegatecall` and returns or reverts with the returned data. It ends the call in
   assembly and never comes back.
2. Otherwise the selector is compared with the five management selectors. Arguments are
   decoded from `msg.data[4:]`, the result is ABI-encoded by hand and returned in
   assembly. An unknown selector (or empty calldata) reverts with `AdminCannotFallback()`.

The management functions are not declared as Solidity functions on purpose. A declared
`upgradeTo` would be chosen by the compiler's dispatcher for every caller and would hide an
implementation function with the same selector from users. With the fallback approach the
caller's identity decides, which is the defining property of the transparent pattern.

## Upgrades

`_upgradeToAndCall` checks that the target has code, writes the slot, emits `Upgraded` and,
for non-empty data, delegate-calls it. A failing call reverts with the callee's revert
data, which also undoes the slot write.

## Pitfalls

- Using state variables for admin or implementation (collides with slot 0 and 1 of the
  implementation).
- Letting the admin fall through to the implementation. A selector clash could then make
  an admin transaction do something entirely different from what was intended.
- Checking `code.length` only in the constructor and not on upgrade.
- Returning from the delegate path with Solidity's `return`, which drops the callee's
  return data.
- Swallowing the revert data of the initialisation call.

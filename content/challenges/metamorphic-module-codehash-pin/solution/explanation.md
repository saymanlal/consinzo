# Why the patch works

An approval is a statement about code: "we reviewed this bytecode and are willing to give it
funds". The starter stores a statement about an identity instead. That is only equivalent if
the code behind the identity can never change, and with CREATE2 plus `SELFDESTRUCT` (or, in
this mission's model, a developer-controlled registry) it can.

The reference stores the audited runtime code hash and re-derives trust from the code every
time:

```solidity
bytes32 pinned = approvedCodeHash[id];
if (pinned == bytes32(0)) revert NotApproved();
module = registry.resolve(id);
if (module.codehash != pinned) revert CodeHashMismatch();
```

- **Swap after approval.** The replacement has a different hash, so `allocate` and `recall`
  revert before any ETH or call reaches it.
- **Removal.** An account without code has `codehash` zero (non-existent) or `keccak256("")`
  (exists, no code). Neither equals a contract's hash, and zero is excluded as a pin because
  `approveModule` requires code.
- **Swap before approval.** `approveModule` takes the hash the owner audited and compares it
  with what is deployed in the same transaction. Recording "whatever is there now" would let
  the developer front-run the approval.
- **Identical redeployment.** Same runtime code means same hash, so it remains usable. This
  is the reason to pin the hash rather than a resolved address.

## Limits of the technique

`codehash` covers the account's own runtime code. It does not cover code the module reaches
through `delegatecall` or an upgradeable proxy, nor its storage. A module that is itself a
proxy must be pinned at the implementation level or not approved at all. On networks with
EIP-6780, destroying and recreating code in separate transactions no longer works, but the
check is still the right expression of what was approved and protects on chains without it.

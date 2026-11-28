# Pin Trusted Modules by Code Hash, Not by Address

`ModuleVault` holds ETH and lets a keeper move funds into strategy modules that the owner
has approved after an audit. Modules are identified by a `bytes32` id that a registry
resolves to a contract.

## Background and how this mission models it

With `CREATE2` a contract address depends on the deployer, a salt and the *init code*, not on
the runtime code that init code returns. Init code that fetches its runtime code from
elsewhere can therefore put different code at the same address each time it runs. On chains
where `SELFDESTRUCT` still removes code, a developer can deploy an innocent module, get its
address approved, destroy it, and redeploy a malicious one at the identical address.

The test harness executes each test as a single call and does not finalise `SELFDESTRUCT`,
so removal and redeployment cannot be reproduced literally. The mission models the same
trust decision with a registry: the module **id** plays the role of the CREATE2 address, and
the developer-controlled registry repointing an id to a new contract plays the role of
destroy-and-redeploy. The runtime code hash (`address.codehash`) is real in both worlds, and
the fix is the same.

## The bug

`approveModule` sets a flag for the id. `allocate` and `recall` resolve the id and trust
whatever contract is there now. After approval the developer swaps the code and the next
`allocate` sends treasury funds to the replacement.

## Your task

Patch `src/ModuleVault.sol`. Keep the interface unchanged.

```solidity
constructor(address registry_);                                        // deployer is owner
function approveModule(bytes32 id, bytes32 expectedCodeHash) external; // owner
function revokeModule(bytes32 id) external;                            // owner
function allocate(bytes32 id, uint256 amount) external;                // permissionless keeper call
function recall(bytes32 id, uint256 amount) external;                  // owner
function approvedCodeHash(bytes32 id) external view returns (bytes32); // zero when not approved
function isApproved(bytes32 id) external view returns (bool);
```

### Required behaviour

- `approveModule` resolves the id and reverts with `NotAContract()` if the result has no
  code, and with `CodeHashMismatch()` if its `codehash` differs from `expectedCodeHash` (the
  hash the owner audited). Otherwise it stores that hash for the id.
- `allocate` and `recall` revert with `NotApproved()` for an id without a stored hash, and
  with `CodeHashMismatch()` if the contract the id resolves to now does not have exactly the
  stored code hash. This includes the case where the id resolves to an address with no code.
- A redeployment with byte-identical runtime code is still the audited code and must keep
  working.
- `revokeModule` clears the approval. Owner-only functions revert with `NotOwner()`.

## What the tests check

- After the registry is repointed to different code, `allocate` and `recall` revert and the
  vault keeps its ETH.
- Approval fails if the code present is not the code that was audited.
- Honest allocation and recall work, including after an identical-code redeployment.

# delegatecall to an untrusted callee

## Semantics

`target.delegatecall(data)` executes the code stored at `target`, but:

- `address(this)`, storage and balance are those of the calling contract;
- `msg.sender` and `msg.value` are those of the original call.

Solidity libraries with external functions, upgradeable proxies and plugin systems all rely
on this. It is safe only when the calling contract decides which code may be executed.

## SWC-112

If the target address comes from user input, the user chooses the code. Typical payloads:

- write the owner or admin slot;
- transfer the contract's ETH or tokens;
- overwrite an implementation pointer so the takeover persists.

No amount of validation of `data` helps when the target itself is attacker-controlled.

## Hardening a plugin or module system

1. Keep an allowlist of targets, changed only by an authorised account, and read it at the
   time of every call.
2. Restrict who may trigger execution. Approved code is still code that acts with the
   contract's full authority.
3. Require targets to have code. A `delegatecall` to an empty address returns success.
4. Keep plugins stateless, or give them storage in unstructured slots that cannot collide
   with the host's variables.
5. Emit an event for every execution so that monitoring can see what ran.

## Related low-level detail

Low-level calls return `(bool success, bytes memory returndata)` instead of reverting. The
host must check `success` and decide whether to bubble the revert data or replace it with
its own error, as this wallet does with `PluginFailed()`.

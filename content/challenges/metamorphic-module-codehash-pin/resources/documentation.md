# Metamorphic contracts and code-hash pinning

## CREATE2 addresses

```
address = keccak256(0xff ++ deployer ++ salt ++ keccak256(initCode))[12:]
```

The address commits to the *init code*, the program that runs once and returns the runtime
code. It does not commit to what that program returns. Init code such as "ask my deployer
which implementation to copy" is constant, while its result is not.

## The metamorphic pattern

1. A factory deploys contract `M` at address `X` with CREATE2. The init code copies runtime
   code from an address the factory names.
2. `X` passes review and is given privileges: an allowlist entry, token approvals, a role.
3. `M` executes `SELFDESTRUCT`. The account at `X` is emptied, including its nonce.
4. The factory points to different runtime code and runs the same CREATE2 again. The new
   contract appears at `X` and inherits every privilege granted to the address.

EIP-6780 (Cancun) restricts `SELFDESTRUCT` to contracts created in the same transaction,
which blocks step 3 on chains that adopted it. Many deployments and other EVM chains still
permit it, and contracts should not rely on the rule of one network.

## EXTCODEHASH

`address.codehash` returns `keccak256(runtimeCode)` for a contract, `keccak256("")` for an
existing account without code and `0` for a non-existent account. Comparing it with a stored
value costs one opcode and answers the question that matters: is this still the code that
was reviewed?

## Using it correctly

- Record the hash at approval time from an explicit argument supplied by the approver.
- Check it at every point where trust is exercised, not only once.
- Reject accounts without code at approval.
- Remember what it does not cover: proxies, `delegatecall` targets and storage.

## Signals during review

A dependency is suspicious if its deployer is a CREATE2 factory with mutable state, if its
code contains `SELFDESTRUCT` or a `delegatecall` to a mutable target, or if it was deployed
by init code whose hash does not match the published source.

# Reference Solution Explanation

## Root cause

A proxy and its implementation share code, not storage. `VaultProxy`'s constructor ran
`initialize` through `delegatecall`, which wrote `owner` and `initialized` into the proxy.
The implementation's own storage stayed empty, and `VaultLogic` had no constructor to
change that. Called directly:

1. `logic.initialize(attacker)` succeeds; the attacker owns the implementation.
2. `logic.upgradeToAndCall(evil, payload)` passes the owner check and executes
   `evil.delegatecall(payload)` in the implementation's context.
3. A payload containing `SELFDESTRUCT` removes the implementation's code (on networks with
   the pre-Cancun semantics). The proxy then delegates to an empty account: every call
   "succeeds" and does nothing, the upgrade function is gone, and funds are stuck.

## Fix

Two independent guards in `VaultLogic`:

```solidity
address private immutable __self = address(this);

modifier onlyProxy() {
    if (address(this) == __self) revert NotProxy();
    _;
}

constructor() {
    initialized = true;
}
```

- The **constructor** executes in the implementation's storage only and consumes the
  initializer. `owner` stays zero, so step 1 fails with `AlreadyInitialized()`.
- **`onlyProxy`** on `upgradeToAndCall` compares `address(this)` with an immutable captured
  at deployment. Immutables are embedded in the bytecode, so through a proxy the comparison
  sees two different addresses, and directly on the implementation it sees the same one.
  Step 2 fails even if some future bug hands out ownership of the implementation.

Neither guard touches proxy storage, so the layout and proxy behaviour are unchanged.
Contracts that inherit from `VaultLogic` get both guards automatically.

## Pitfalls

- Initialising the implementation with a "safe" owner instead of locking it leaves a key
  that can still trigger the direct upgrade path.
- A storage variable cannot implement `onlyProxy`; it would be read from the proxy's
  storage when called through the proxy.
- After Cancun (EIP-6780) `SELFDESTRUCT` no longer deletes existing contracts, but arbitrary
  code executing as the implementation is still unacceptable, and many networks adopt
  changes at different times.

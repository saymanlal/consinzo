# Initialiser Functions

A constructor runs once, during deployment, and its code is not part of the deployed
contract. Contracts created as minimal clones or placed behind proxies cannot rely on a
constructor, so they expose a regular function (commonly `init` or `initialize`) that sets
the initial state.

Because it is a regular function, the contract must enforce the "once" itself.

```solidity
bool public initialized;

function init(address owner_) external {
    if (initialized) revert AlreadyInitialized();
    initialized = true;
    owner = owner_;
}
```

## What can go wrong

- **Re-initialisation.** Without the guard, anyone can overwrite privileged state later.
- **Front-running.** If deployment and initialisation are separate transactions, an
  attacker can initialise the contract first. Deploy and initialise in one transaction.
- **Uninitialised implementation.** For proxies, the implementation contract itself must
  be initialised or have initialisation disabled.

## Reviewing

Search for functions that assign `owner`, admin roles or core addresses and are not
constructors. Each needs either an access check or a one-shot guard that is actually
evaluated before the assignment.

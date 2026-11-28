# Initialising minimal proxies safely

## Clones and constructors

An ERC-1167 minimal proxy is 45 bytes of runtime code that forwards every call to a fixed
implementation with `delegatecall`. Deploying it runs only the tiny creation code, never the
implementation's constructor. State that a constructor would normally set (owner, token
addresses, parameters) must be written by an explicit `initialize` function executed in the
clone's storage.

## The race

`initialize` has to be callable once by somebody. If deployment and initialisation are two
transactions, there is a block-level window in which the clone exists without an owner.
Observers of the mempool can submit `initialize(attacker)` with a higher fee and win.
The safe pattern is for the deployer (factory) to call `initialize` in the same transaction.

## Deterministic addresses

`CREATE2` computes the address as

```
keccak256(0xff ++ deployer ++ salt ++ keccak256(init_code))[12:]
```

For a factory, `deployer` and `init_code` are the same for all users, so the salt alone
selects the address. If users pick salts freely, they also pick each other's addresses.
Deriving the salt from `(creator, userSalt)` gives each creator a private namespace and
makes counterfactual funding (sending assets before deployment) safe.

## The implementation contract

The implementation is an ordinary deployed contract with its own storage. If it stays
uninitialised, anyone can initialise it. For a simple wallet that is mostly harmless, but
for implementations with `delegatecall` or `selfdestruct` paths it has led to real losses.
Lock it in its constructor.

# Reference Solution Explanation

## UpgradeableBeacon

A small owned contract with one address. `_setImplementation` is shared by the constructor
and `upgradeTo` so that the code-length check cannot be forgotten in one of them. An
implementation without code would make every proxy "succeed" at doing nothing.

## BeaconProxy

- The constructor checks both hops: the beacon has code, and the implementation it
  currently returns has code. It then writes the beacon to the EIP-1967 beacon slot with
  `sstore` and runs the optional initialiser with `delegatecall`, re-throwing the callee's
  revert data on failure.
- The fallback reads the beacon from the slot, performs a high-level (static) call to
  `implementation()`, and delegates in assembly, returning or reverting with the full
  returndata.

The proxy declares no state variables and no functions. The implementation address is
never written to the proxy's storage: caching it would defeat the purpose of the beacon.

## Pitfalls

- Storing the beacon in a normal state variable (slot 0), which the implementation's
  first variable then overwrites.
- Caching the implementation in the proxy at construction time. Proxies would then ignore
  beacon upgrades.
- Running the initialiser with `call` instead of `delegatecall`. It would initialise the
  implementation contract's own storage and leave the proxy uninitialised.
- Validating the implementation only when the beacon is created but not on `upgradeTo`.
- Dropping returndata in either direction.

## Trust model

Whoever owns the beacon controls the code of every proxy attached to it. The owner should
be a multisig or a timelock in a real deployment.

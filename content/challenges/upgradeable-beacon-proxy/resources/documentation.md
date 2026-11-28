# The Beacon Proxy Pattern

## Structure

```
proxy A --\
proxy B ---+--> beacon --> implementation
proxy C --/
```

Each proxy holds state and a pointer to the beacon. The beacon holds a pointer to the
implementation. A call to a proxy costs one extra external call (to the beacon) compared
with a plain EIP-1967 proxy.

## When to use it

- Many instances of the same contract (per-user vaults, per-pair pools, per-collection
  tokens) that must always run the same version.
- A factory that creates instances cheaply and wants one upgrade switch for all of them.

For a single upgradeable contract a transparent or UUPS proxy is simpler.

## EIP-1967 beacon slot

`bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`. A beacon proxy leaves the
implementation slot empty; tooling that finds a beacon in the beacon slot calls
`implementation()` on it to find the logic contract.

## Calling a view function before delegating

The lookup `IBeacon(beacon).implementation()` is an ordinary external call compiled by
Solidity as `staticcall`. It allocates a little memory, which is harmless because the
subsequent assembly block takes over memory from offset 0 and never returns to Solidity.

## Initialisation

Proxies cannot use the implementation's constructor, because constructor code runs against
the implementation's own storage at deployment. Implementations expose an `initialize`
function instead, and the proxy's constructor delegate-calls it so that creation and
initialisation are atomic.

# Transparent Proxies and EIP-1967

## delegatecall

`delegatecall` runs the code of another contract against the storage, balance and
`msg.sender` / `msg.value` of the calling contract. A proxy delegates every call, so the
implementation's code operates on the proxy's storage. Upgrading means pointing the proxy
at different code; the storage stays.

## EIP-1967 slots

| purpose | slot |
| --- | --- |
| implementation | `keccak256("eip1967.proxy.implementation") - 1` |
| admin | `keccak256("eip1967.proxy.admin") - 1` |
| beacon | `keccak256("eip1967.proxy.beacon") - 1` |

Subtracting one means the slot has no known preimage, so it cannot be reached as the
location of a mapping entry or dynamic array. Block explorers and tooling read these slots
to show the implementation behind a proxy.

## The selector clash problem

Function selectors are only four bytes. Two unrelated functions can share a selector, and
an implementation may intentionally define a function named like a proxy function. If the
proxy handled such a selector for everybody, users could never reach the implementation's
version; if it never handled it, the admin could not manage the proxy.

The transparent pattern splits the callers:

- admin: management functions only, everything else reverts;
- everyone else: implementation only.

A consequence is that the admin account cannot use the application through the proxy. In
practice the admin is a dedicated contract (a `ProxyAdmin`) rather than a person's wallet.

## Forwarding results in assembly

```
calldatacopy(0, 0, calldatasize())
let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
returndatacopy(0, 0, returndatasize())
switch ok case 0 { revert(0, returndatasize()) } default { return(0, returndatasize()) }
```

Overwriting memory from offset 0 is fine here because control never returns to Solidity.

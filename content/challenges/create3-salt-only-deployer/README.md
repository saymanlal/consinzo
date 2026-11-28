# CREATE3-Style Deployer: Addresses Independent of Init Code

## Problem Statement

`CREATE2` makes addresses predictable, but the address depends on the hash of the init
code. Change a constructor argument or a compiler setting and the address changes. Teams
that want the same address on every chain regardless of the bytecode use the "CREATE3"
construction:

1. `CREATE2` a tiny proxy contract with a fixed init code. Its address depends only on the
   deployer contract and the salt.
2. Call the proxy with the real init code. The proxy executes `CREATE`. A fresh contract
   has nonce 1, so the new address depends only on the proxy address.

Implement `Create3Deployer` in `src/Create3Deployer.sol`.

## Required Interface

```solidity
error ProxyDeploymentFailed();
error DeploymentFailed();

event Deployed(address indexed sender, bytes32 indexed salt, address deployed);

function deploy(bytes32 salt, bytes calldata initCode) external payable returns (address deployed);
function addressOf(address sender, bytes32 salt) external view returns (address);
function proxyAddressOf(address sender, bytes32 salt) external view returns (address);
```

## The Proxy

The proxy's init code is given (16 bytes):

```
0x67363d3d37363d34f03d5260086018f3
```

It deploys the 8-byte runtime code `0x363d3d37363d34f0`, which copies its calldata to
memory and executes `CREATE(callvalue, 0, calldatasize)`. The runtime code does not revert
when the creation fails and returns nothing.

## Rules

1. The CREATE2 salt is `keccak256(abi.encodePacked(sender, salt))`, where `sender` is the
   caller of `deploy`. Two different callers using the same `salt` get different addresses.
2. `proxyAddressOf(sender, salt)` is the CREATE2 address of the proxy:
   `keccak256(0xff ++ address(this) ++ create2Salt ++ keccak256(proxyInitCode))[12:]`.
3. `addressOf(sender, salt)` is the address created by that proxy at nonce 1:
   `keccak256(0xd6 ++ 0x94 ++ proxy ++ 0x01)[12:]`. It does not depend on any init code.
4. `deploy(salt, initCode)`:
   - deploys the proxy with CREATE2; if that fails (the salt was already used by this
     caller) it reverts with `ProxyDeploymentFailed()`;
   - calls the proxy with `initCode` as calldata and forwards all of `msg.value`, so the
     value reaches the new contract's constructor;
   - reverts with `DeploymentFailed()` if the call failed or if there is no code at
     `addressOf(msg.sender, salt)` afterwards (reverting constructor, empty runtime code);
   - emits `Deployed` and returns the new address.
5. A failed `deploy` leaves nothing behind: the same salt can be used again.

## What the Tests Check

- Deployed addresses equal `addressOf`, and the same salt yields the same address for
  different init codes.
- Separation between callers, salt reuse, value forwarding and constructor arguments.
- Detection of reverting constructors and empty runtime code.
- The two derivation formulas, recomputed in the test.

Note on gas: a `CREATE2` that collides with an existing contract consumes all gas passed to
it, so the salt-reuse path is expensive by design of the EVM.

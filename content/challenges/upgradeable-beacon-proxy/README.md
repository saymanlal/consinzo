# Beacon Proxy with an Upgradeable Beacon Serving Many Proxies

## Problem Statement

When hundreds of proxies share the same logic, upgrading them one by one is expensive and
error-prone. With the beacon pattern each proxy stores the address of a *beacon* instead of
an implementation. The beacon stores the implementation. Upgrading the beacon upgrades all
proxies that point to it in a single transaction.

Implement both contracts in `src/BeaconProxy.sol`.

## Required Interface

```solidity
interface IBeacon {
    function implementation() external view returns (address);
}

contract UpgradeableBeacon is IBeacon {
    error NotOwner();
    error ZeroAddress();
    error NotContract(address target);

    event Upgraded(address indexed implementation);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address implementation_, address owner_);
    function owner() external view returns (address);
    function implementation() external view returns (address);
    function upgradeTo(address newImplementation) external;
    function transferOwnership(address newOwner) external;
}

contract BeaconProxy {
    error NotContract(address target);

    event BeaconUpgraded(address indexed beacon);

    constructor(address beacon, bytes memory initData) payable;
    fallback() external payable;
}
```

## Rules

### UpgradeableBeacon

1. The constructor reverts with `ZeroAddress()` if `owner_` is zero and with
   `NotContract(implementation_)` if the implementation has no code.
2. `upgradeTo` may only be called by the owner (`NotOwner()`), requires the new
   implementation to have code (`NotContract(newImplementation)`) and emits `Upgraded`.
3. `transferOwnership` may only be called by the owner and rejects the zero address with
   `ZeroAddress()`.

### BeaconProxy

1. The beacon address is stored in the EIP-1967 beacon slot
   `bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1)`
   = `0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50`.
   The proxy uses no other storage slot and never changes the beacon after construction.
2. The constructor reverts with `NotContract(beacon)` if the beacon has no code and with
   `NotContract(implementation)` if the implementation currently returned by the beacon has
   no code. It emits `BeaconUpgraded(beacon)`.
3. If `initData` is not empty, the constructor delegate-calls it on the beacon's current
   implementation. If that call reverts, the constructor reverts with the same revert data.
4. Every call to the proxy (any calldata, with or without value) is delegated to the
   address returned by `IBeacon(beacon).implementation()` **at the time of the call**.
   Return data and revert data are passed through unchanged.
5. The proxy has no functions of its own.

## What the Tests Check

- Several proxies on one beacon: separate state, shared logic, one upgrade switches all.
- The beacon slot, and that no implementation address is cached in the proxy.
- Access control and validation on the beacon, constructor validation on the proxy.
- Pass-through of return data, revert data and ether.

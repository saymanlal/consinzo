# Transparent Upgradeable Proxy with EIP-1967 Slots

## Problem Statement

A proxy holds the state and delegates every call to an implementation contract that can be
replaced. Two problems have to be solved:

- **Storage collisions.** The proxy needs to remember the implementation and the admin
  without using storage slots the implementation also uses. EIP-1967 reserves fixed slots
  for this.
- **Selector clashes.** If the proxy exposes `upgradeTo(address)` and the implementation
  has a function with the same selector, which one runs? The transparent pattern answers:
  it depends on the caller. The admin only ever talks to the proxy; everyone else only ever
  talks to the implementation.

Implement `TransparentProxy` in `src/TransparentProxy.sol`.

## Required Interface

The management functions are described by this interface (it is in the starter file):

```solidity
interface ITransparentProxy {
    function admin() external returns (address);
    function implementation() external returns (address);
    function changeAdmin(address newAdmin) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}
```

The proxy itself:

```solidity
error NotContract(address target);
error ZeroAdmin();
error AdminCannotFallback();

event Upgraded(address indexed implementation);
event AdminChanged(address previousAdmin, address newAdmin);

constructor(address implementation_, address admin_, bytes memory initData) payable;
fallback() external payable;
```

## Rules

1. Storage slots (EIP-1967):
   - implementation: `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)`
     = `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
   - admin: `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`
     = `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`

   The proxy must not use any other storage slot.
2. Constructor: reverts with `ZeroAdmin()` if `admin_` is zero and with
   `NotContract(implementation_)` if the implementation has no code. It stores both
   addresses. If `initData` is not empty it is delegate-called on the implementation; if
   that call reverts, the constructor reverts with the same revert data.
3. **Caller is the admin.** The call is handled by the proxy and never delegated:
   - `admin()` and `implementation()` return the stored addresses;
   - `changeAdmin(newAdmin)` replaces the admin (`ZeroAdmin()` for the zero address) and
     emits `AdminChanged`;
   - `upgradeTo(newImplementation)` replaces the implementation
     (`NotContract(newImplementation)` if it has no code) and emits `Upgraded`;
   - `upgradeToAndCall(newImplementation, data)` does the same and then, if `data` is not
     empty, delegate-calls `data` on the new implementation, bubbling up revert data;
   - any other selector, including empty calldata, reverts with `AdminCannotFallback()`.
4. **Caller is anyone else.** The call is delegated to the implementation with the full
   calldata and value. Return data and revert data are passed through unchanged. This
   holds even if the selector equals one of the five management selectors.
5. The proxy accepts ether from non-admin callers and forwards it through the delegate
   call (so the implementation decides whether it is accepted).

## What the Tests Check

- State lives in the proxy; upgrades keep it; initialisation data runs in the proxy context.
- The exact EIP-1967 slots, read through an implementation function.
- Transparency: the admin cannot reach the implementation, non-admins cannot reach the
  management functions, clashing selectors are resolved by caller.
- Revert conditions and bubbling of return and revert data.

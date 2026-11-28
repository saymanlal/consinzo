# Remove a Proxy Selector Clash That Routes User Calls to an Admin Function

`ShieldedProxy` is an EIP-1967 upgradeable proxy in front of an ETH-backed token
(`deposit()` mints, `burn(uint256)` burns and returns ETH). The proxy was supplied by a
contractor and declares several external functions of its own.

## The bug

Solidity dispatches a call to the proxy's own function when the selector matches, and only
otherwise to `fallback()`. One proxy function is

```solidity
function collate_propagate_storage(bytes16) external   // selector 0x42966c68
```

`burn(uint256)` also has selector `0x42966c68`. A user who calls `burn` on the proxy never
reaches the token. The proxy function runs instead, and it writes `msg.sender` into the admin
slot. The caller is now proxy admin, upgrades to a contract with a `sweep` function and takes
all deposited ETH.

The same shadowing affects every other proxy function: the implementation can never expose
`admin()`, `implementation()`, `upgradeTo(address)` or `changeAdmin(address)` to its users.

## Your task

Rewrite the dispatch of `src/ShieldedProxy.sol` as a transparent proxy. The constructor
signature and the EIP-1967 storage slots stay as they are.

```solidity
constructor(address implementation_, address admin_);
```

### Required behaviour

- **Callers other than the admin**: every call, with any selector and any calldata including
  empty calldata, is forwarded to the implementation with `delegatecall`. Return data and
  revert data are passed back unchanged. Nothing such a caller sends can change the admin
  or implementation slot.
- **The admin**: calls are never forwarded. The admin can call exactly these functions on
  the proxy address:

  ```solidity
  function admin() external view returns (address);
  function implementation() external view returns (address);
  function upgradeTo(address newImplementation) external;   // NotAContract() if it has no code
  function changeAdmin(address newAdmin) external;           // ZeroAddress() for address(0)
  ```

  Anything else from the admin, including a plain ETH transfer, reverts with
  `AdminCannotFallback()`.
- The function `collate_propagate_storage` must be gone.

## What the tests check

- `burn` through the proxy burns tokens and returns ETH; it does not change the admin.
- An attacker cannot become admin or upgrade; user funds stay in the proxy.
- An implementation that itself defines `admin()` or `upgradeTo(address)` is reachable by
  users through the proxy.
- The admin can upgrade and hand over the role, and cannot use the implementation.

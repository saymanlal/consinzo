# Lock an Uninitialised Implementation Behind an Upgradeable Proxy

`src/VaultLogic.sol` contains an upgradeable ETH vault in the UUPS style:

- `VaultProxy` stores the implementation address in the ERC-1967 slot and forwards every
  call with `delegatecall`. Its constructor runs `initialize` in the proxy's storage.
- `VaultLogic` holds the code: `initialize`, `deposit`, `withdraw` and the upgrade function
  `upgradeToAndCall(newImplementation, data)`, which is restricted to `owner`.

The proxy is set up correctly. The implementation contract is not: it is an ordinary
contract with its own storage, in which `initialized` is false and `owner` is zero. Anyone
can call `initialize` **directly on the implementation**, become its owner, and then call
`upgradeToAndCall` on it. That function finishes with a `delegatecall` into an address the
owner chooses, so the attacker's code runs with the implementation's identity. On networks
where `SELFDESTRUCT` removes code, that payload deletes the implementation and every proxy
pointing at it stops working, with users' ETH locked inside. The same pattern froze real
UUPS deployments before the libraries added a guard.

## Your task

Patch `VaultLogic` (leave `VaultProxy` as it is) so that the implementation contract cannot
be taken over, while proxies keep working exactly as before.

Required:

1. On any directly deployed `VaultLogic`, `initialized()` is `true` and `owner()` is
   `address(0)` from construction, and `initialize` reverts with `AlreadyInitialized()`.
2. `upgradeToAndCall` reverts when it is called directly on an implementation contract, for
   every caller. Use the provided `NotProxy()` error for a call that does not come through
   a proxy. The implementation must never execute the trailing `delegatecall` in its own
   context.
3. Through a proxy nothing changes: the constructor-supplied `initialize` call sets the
   owner once, a second `initialize` reverts with `AlreadyInitialized()`, only the owner may
   upgrade (`NotOwner()`), the target must have code (`NotAContract()`), a failing migration
   call reverts with `UpgradeCallFailed()`, and state is preserved across upgrades.
4. Keep the storage layout (`owner`, `initialized`, `balanceOf`) and all signatures. New
   implementations in the tests inherit from your `VaultLogic`.

## A note on the harness

The test EVM executes each test as a single call and does not finalise `SELFDESTRUCT`, so
the tests cannot observe code being deleted. They detect the takeover one step earlier: the
attacker's payload calls a recorder contract, and the test asserts that the recorder was
never called with the implementation as `msg.sender`.

## What the tests check

Public tests use the vault through the proxy, upgrade it as the owner, try to initialise the
implementation and try the full takeover with a self-destructing payload. Hidden tests run
the takeover from a contract, check freshly deployed implementations and direct upgrade
calls, and cover multiple proxies, re-initialisation, upgrade access control, migrations and
state preservation.

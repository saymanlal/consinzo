# Patch a Clone Factory Whose Wallets Can Be Initialised by Anyone

`WalletFactory` deploys cheap ERC-1167 clones of `CloneWallet` with `CREATE2`. A clone shares
the implementation's code but never runs its constructor, so the wallet's owner is set
through `initialize(address)`.

The factory only deploys the clone and expects the creator to call `initialize` afterwards.
Two things go wrong:

1. Between the two transactions the wallet has no owner. Whoever calls `initialize` first
   becomes the owner, so a front-runner can take every freshly created wallet and any ETH
   later sent to it.
2. The `CREATE2` salt is the raw user input. Anyone can call `createWallet` with a salt they
   saw in the mempool and occupy the address the real creator computed with `predict`,
   which also captures funds sent to that address in advance.

## Your task

Patch `src/WalletFactory.sol` (both contracts live in this file) so that:

- `createWallet(bytes32 salt)` returns a wallet that is **already initialised** with
  `owner == msg.sender`. No separate initialise transaction exists.
- The deployment address depends on the creator as well as the salt.
  `predict(creator, salt)` must return exactly the address `createWallet(salt)` yields when
  called by `creator`, and different creators must get different addresses for the same
  salt. A third party using the same salt must neither block nor capture the creator's
  wallet.
- `initialize` on a deployed wallet always reverts with `AlreadyInitialized()`, for every
  caller including the owner.
- The implementation contract (`factory.implementation()`) can never be initialised: calling
  `initialize` on it reverts and its `owner` stays `address(0)`.
- Creating twice with the same creator and salt reverts.

Keep the existing signatures, errors and events. `withdraw` remains owner-only
(`NotOwner()`), `isWallet` is true for every wallet the factory deployed.

## What the tests check

Public tests check that a new wallet is owned by its creator immediately, that a late
`initialize` from an attacker reverts, that the creator can move funds and that `predict`
matches the deployment. Hidden tests replay the salt-squatting scenario, pre-fund the
predicted address before deployment, compare predictions across creators and salts, and
probe the implementation contract and double creation.

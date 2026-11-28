# Reference Solution Explanation

## Root cause

Initialisation was a separate, permissionless transaction. `initialize` only checked that it
had not run before, so the first caller won. On a public mempool the creator's transaction
is visible and can be front-run. Independently, `CREATE2` used the caller-supplied salt
directly, so the address returned by `predict` was the same for every user and could be
deployed by anyone.

## Fix

1. **Atomic initialisation.** `createWallet` deploys the clone and immediately calls
   `initialize(msg.sender)`. From the outside, a wallet is never observable in an
   uninitialised state, and the owner is not taken from an argument.
2. **Creator-bound salt.** The effective salt is `keccak256(abi.encode(creator, salt))`.
   `predict` uses the same derivation. Another account using the same salt lands on a
   different address, so it can neither block the deployment nor receive pre-sent funds.
3. **Locked implementation.** `CloneWallet`'s constructor sets `initialized = true`. Only the
   implementation executes that constructor; clones start with clean storage and are
   initialised by the factory.

The one-shot `initialized` flag is kept, so later calls revert with `AlreadyInitialized()`.

## Pitfalls

- Restricting `initialize` to `tx.origin` or to "the first caller" does not remove the race.
- Passing the owner as an argument to `createWallet` re-opens a variant of the problem when
  the salt is not also bound to that owner.
- Use `abi.encode` (fixed width) rather than `abi.encodePacked` when deriving salts from
  several fields to avoid ambiguous encodings.

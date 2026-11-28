# Patch a Wallet That Delegatecalls Any Supplied Plugin

`PluginWallet` is an ETH wallet that adds features through plugins. A plugin is a stateless
contract whose code the wallet executes with `delegatecall`, so the plugin's code runs with
the wallet's storage, balance and identity. `BatchPayPlugin`, shipped in the same file, pays
several recipients from the wallet in one call.

The owner keeps a list of approved plugins (`setPlugin`), but `run(plugin, data)` neither
consults that list nor checks who is calling. Anyone can pass the address of a contract they
deployed and have it overwrite `owner`, or call the approved batch payer with themselves as
the recipient.

## Your task

Patch `src/PluginWallet.sol`. `run` must keep working for the owner with approved plugins and
must be useless to everyone else. Do not change `BatchPayPlugin`, the storage layout
(`owner` in slot 0, `approvedPlugin` in slot 1), signatures, errors or events.

## Required behaviour of `run(address plugin, bytes data) returns (bytes)`

1. Reverts with `NotOwner()` unless `msg.sender == owner`.
2. Reverts with `PluginNotApproved()` unless `approvedPlugin[plugin]` is true at the time of
   the call. A revoked plugin stops working immediately.
3. Otherwise delegatecalls `plugin` with `data`, reverts with `PluginFailed()` if the plugin
   reverts, emits `PluginRun` and returns the plugin's return data unchanged.

The rest of the contract keeps its behaviour: `setPlugin` and `transferOwnership` are
owner-only (`NotOwner()`), `setPlugin` rejects approval of an address without code with
`NotAContract()`, and the wallet accepts plain ETH transfers.

## What the tests check

Public tests run the batch payer as the owner, attempt an ownership takeover with an
attacker-deployed plugin, attempt to spend through the approved plugin as a stranger, and
check that the owner cannot run an unapproved plugin. Hidden tests add a one-transaction
attack contract that tries several routes while swallowing reverts, revocation, forwarding
of return data and plugin failures, ownership transfer and plugin administration.

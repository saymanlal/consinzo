# Background: The Source Side of a Lock-Based Bridge

## What the deposit contract is for

A lock-based bridge has two halves. On the source chain a contract takes tokens into
custody and publishes a record. Off-chain relayers (or a light client) convince a contract
on the destination chain that the record exists, and that contract releases or mints the
matching amount. The destination can only be as correct as the records the source emits.

## Why nonces, and why per destination

Each destination contract must be able to answer "have I already processed this deposit?".
A sequence number makes each deposit unique even when sender, recipient and amount repeat.
Keeping one sequence per destination chain gives every destination a dense series
`0, 1, 2, ...`, which also allows ordered processing and makes gaps detectable.

## Domain separation in identifiers

A deposit identifier is a hash of the deposit's fields. If it does not include the source
chain id and the address of the emitting contract, an identical-looking deposit on another
deployment hashes to the same value and can be replayed. `abi.encode` pads every value to
32 bytes, so the encoding is unambiguous.

## ERC-20 return values

EIP-20 specifies that `transferFrom` returns a boolean. Some tokens revert on failure,
others return `false`. A contract that takes custody must treat `false` as a failure.

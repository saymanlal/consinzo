# Optimistic Concurrency on Chain

## Compare-and-set

A conditional write is a compare-and-set: "store this value, but only if the key is still
at the version I read". Two transactions that were built against the same version cannot
both succeed; the second one reverts and its sender has to read the new value and retry.
On a blockchain the ordering of transactions inside a block is not under the sender's
control, so this pattern is the standard way to make read-modify-write sequences safe.

## Why versions must only go up

If a version could repeat, a writer could not tell "nothing happened" from "something
happened and was undone". Keeping the counter running through removals makes every state
of a key distinguishable.

## Storage layout

`bytes` values in a mapping are stored out of line: short values (up to 31 bytes) share a
slot with their length, longer ones are placed at `keccak256(slot)`. A struct with a
`uint64` and a `bool` packs into a single slot, so the version check and the liveness
flag cost one storage read.

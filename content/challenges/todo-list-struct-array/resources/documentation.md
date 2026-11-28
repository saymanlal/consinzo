# Structs, Arrays and Data Location: Background

## Structs

A struct groups fields into one type:

```solidity
struct Todo { string text; bool done; }
```

Structs can be array elements and mapping values. Create one with named fields:
`Todo({text: text, done: false})`.

## Dynamic storage arrays

`T[]` in storage supports `push`, `pop`, `length` and index access. Reading or writing an index
that is not below `length` reverts with `Panic(0x32)`. `push` appends at index `length`.

## storage, memory, calldata

- `storage` variables are references to contract state. Writing through them changes state.
- `memory` variables are temporary copies. Assigning a storage struct to a memory variable copies
  every field; later changes to the copy are not saved.
- `calldata` is the read-only input of an external call. Passing strings as `calldata` avoids a
  copy.

This distinction is the most common source of "my update did not stick" bugs.

## Returning struct fields

A function can return several values: `returns (string memory text, bool done)`. Callers
destructure them: `(string memory t, bool d) = list.get(owner, 0);`.

## Avoid unbounded loops

A counter that is updated when the data changes is cheaper and safer than a view function that
loops over a list of unknown size.

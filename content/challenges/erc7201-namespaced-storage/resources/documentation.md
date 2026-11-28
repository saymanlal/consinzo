# Namespaced Storage (ERC-7201)

## Default layout and why it breaks

Solidity assigns state variables to slots in declaration order, following the inheritance
linearisation. This works for a single contract that is never upgraded. It breaks when:

- a proxy and its implementation both declare variables (both start at slot 0);
- an upgrade adds a variable to a base contract (all later variables shift);
- several independently written modules or facets share one storage space.

## The ERC-7201 approach

Each module owns a namespace id, for example `consinzo.storage.Counter`, and one struct.
The struct is rooted at

```
keccak256(abi.encode(uint256(keccak256(id)) - 1)) & ~bytes32(uint256(0xff))
```

and annotated with `/// @custom:storage-location erc7201:<id>` so that tools can find it.

## Layout inside the struct

The usual rules apply relative to the base slot:

- value types take slots in order and are packed when several fit into 32 bytes
  (two addresses do not fit, so each takes a full slot);
- a mapping takes one (empty) slot `p`; the value for key `k` is at
  `keccak256(abi.encode(k, p))`;
- a dynamic array stores its length at `p` and its elements from `keccak256(p)`.

## Working with storage pointers

A function can return `Struct storage` only if the pointer is assigned in assembly via
`$.slot := ...`. Assigning the returned pointer to a `storage` local keeps a reference;
assigning it to a `memory` local makes a copy that is not written back.

## Evolving a namespace

Append new members at the end of the struct. Never remove, reorder or change the type of
existing members. A new module gets a new namespace id rather than extending another
module's struct.

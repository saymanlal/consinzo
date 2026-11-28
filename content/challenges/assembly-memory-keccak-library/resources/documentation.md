# Memory in the EVM and in Solidity

## EVM memory

Memory is a byte array that starts empty for every call frame and grows on access. `mload`
and `mstore` read and write 32-byte words at any byte offset; `mstore8` writes one byte.
The cost of growing memory is linear for small sizes and quadratic beyond that.

`keccak256(offset, length)` hashes a memory range and costs `30 + 6 * ceil(length / 32)`
gas plus any memory expansion.

## Solidity's conventions

| range | purpose |
| --- | --- |
| `0x00 - 0x3f` | scratch space for hashing |
| `0x40 - 0x5f` | free memory pointer |
| `0x60 - 0x7f` | zero slot |
| `0x80 ...` | allocations |

Solidity allocates by reading the pointer at `0x40`, using memory from there and writing
back the increased pointer. It never frees memory. Assembly that follows the same rules
can be marked `memory-safe`.

## Arrays in memory

`bytes memory x` points to a 32-byte length followed by `length` bytes of data. Elements
of `bytes` are tightly packed; other arrays use one word per element.

## Word-wise copying

```
for { let end := add(src, len) } lt(src, end) { src := add(src, 32) dst := add(dst, 32) } {
    mstore(dst, mload(src))
}
```

This copies `ceil(len / 32)` words. The bytes behind `len` in the last word must be dealt
with: either mask them, or make sure they fall into memory that is being allocated and
zero them afterwards. From the Cancun hard fork on there is an `MCOPY` opcode; this
challenge targets the Paris EVM, where it is not available.

## abi.encodePacked

Packed encoding concatenates values using their natural width: `address` is 20 bytes,
`uint96` is 12 bytes, `bytes32` is 32 bytes, and `bytes` contributes its raw contents
without a length. That is the layout the hash functions in this challenge reproduce.

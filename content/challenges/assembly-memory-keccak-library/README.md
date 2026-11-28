# Assembly Library: Word-Wise Memory Copy and Packed Keccak-256

## Problem Statement

Low-level libraries (RLP, Merkle proofs, signature checks) spend most of their gas moving
bytes around and hashing them. Implement the library `AsmBytes` in `src/AsmBytes.sol` with
inline assembly. Each function has a simple high-level definition; your implementation must
return exactly the same result, cheaply, and without breaking Solidity's memory model.

## Required Interface

All functions are `internal pure` library functions.

```solidity
library AsmBytes {
    error OutOfBounds();

    function copy(bytes memory src) internal pure returns (bytes memory dst);
    function slice(bytes memory data, uint256 start, uint256 length) internal pure returns (bytes memory result);
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory result);

    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32 digest);
    function hashTriple(bytes32 a, bytes32 b, bytes32 c) internal pure returns (bytes32 digest);
    function hashPacked(address account, uint96 amount, bytes32 salt) internal pure returns (bytes32 digest);
    function hashConcat(bytes memory a, bytes memory b) internal pure returns (bytes32 digest);
}
```

## Reference Semantics

| function | must equal |
| --- | --- |
| `copy(src)` | a new array with the same bytes as `src` |
| `slice(data, start, length)` | the bytes `data[start .. start + length)` in a new array |
| `concat(a, b)` | `abi.encodePacked(a, b)` |
| `hashPair(a, b)` | `keccak256(abi.encodePacked(a, b))` |
| `hashTriple(a, b, c)` | `keccak256(abi.encodePacked(a, b, c))` |
| `hashPacked(account, amount, salt)` | `keccak256(abi.encodePacked(account, amount, salt))` |
| `hashConcat(a, b)` | `keccak256(abi.encodePacked(a, b))` |

## Rules

1. `slice` reverts with `OutOfBounds()` when `start + length` exceeds `data.length`. The
   check must not be fooled by arithmetic overflow. A zero-length slice at
   `start <= data.length` returns an empty array.
2. `copy`, `slice` and `concat` return **new** arrays. They never alias their inputs and
   never modify them. After they return, the free memory pointer must be past the end of
   the returned data, so that later allocations do not overwrite it.
3. The four hash functions must **not allocate**: the free memory pointer (`mload(0x40)`)
   has the same value before and after the call, and the zero slot (`mload(0x60)`) is
   still zero. They may use the scratch space `0x00..0x3f` and memory behind the free
   memory pointer.
4. Copies must work on 32-byte words, not single bytes. The tests enforce a gas bound:
   `copy` of 4096 bytes must use less than 20,000 gas and `hashConcat` of two 2048-byte
   arrays less than 25,000 gas, measured around the internal call.
5. Inputs of any length must work, including empty arrays and lengths that are not
   multiples of 32.

## What the Tests Check

The tests call the library through a small harness contract and compare every result with
the high-level expression above. They also inspect the free memory pointer and the zero
slot, allocate memory after each call to detect overlapping allocations, mutate inputs to
detect aliasing, and measure gas.

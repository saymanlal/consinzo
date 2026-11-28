# Strings and Bytes in Solidity: Background

## What a string is

`string` is a dynamically sized array of UTF-8 bytes. Compared with `bytes` it deliberately lacks
`length` and index access, because a byte offset is not a character position. Convert between the
two at no cost:

```solidity
bytes memory raw = bytes(s);
string memory s2 = string(raw);
```

## Bytes versus characters

ASCII characters take one byte. Other characters take two to four bytes in UTF-8:

| text | bytes |
| ---- | ----- |
| `a` | 1 |
| `é` | 2 |
| `€` | 3 |
| `😀` | 4 |

On-chain limits such as "name of at most 32 bytes" are byte limits. Source code that contains
non-ASCII literals must use the `unicode"..."` prefix.

## Comparing

There is no `==` for dynamic arrays. Compare hashes:

```solidity
keccak256(bytes(a)) == keccak256(bytes(b))
```

`keccak256` takes `bytes` and returns `bytes32`. Two different inputs producing the same hash is
computationally infeasible.

## Concatenating

- `string.concat(a, b, ...)` for strings
- `bytes.concat(a, b, ...)` for byte arrays
- `abi.encodePacked(a, b)` as the older general form

Note that packed encoding of several dynamic values is ambiguous: `("ab", "c")` and `("a", "bc")`
give the same bytes. That matters when the result is hashed for a signature or used as an
identifier.

## Slices

Calldata arrays support slices: `data[start:end]`, `data[:end]`, `data[start:]`. A slice is a view
into the calldata and costs no copy. Slices are not available for memory or storage arrays.

## pure functions

A `pure` function reads neither storage nor the environment. Its result depends only on its
arguments, which makes helpers like these easy to test and safe to call from anywhere.

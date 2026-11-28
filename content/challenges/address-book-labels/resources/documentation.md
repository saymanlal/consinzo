# Mappings and Existence: Background

## Mappings return defaults

`mapping(K => V)` behaves as if every possible key already exists and maps to the zero value of
`V`: `0`, `false`, `address(0)` or an empty string. There is no way to ask a mapping whether a key
was ever written, and mappings cannot be iterated or measured.

## Three ways to track existence

1. **Sentinel value**: forbid the default value on write, then treat the default as "missing". This
   challenge does that with empty strings.
2. **Explicit flag**: store a struct `{ bool exists; ... }` or a second `mapping(K => bool)`.
3. **Index mapping**: keep the keys in an array and store `index + 1` per key.

## Nested mappings

`mapping(address => mapping(address => string))` is read and written as `m[a][b]`. Each outer key
has an independent inner mapping.

## Strings

`string` is a dynamic UTF-8 byte array without a `length` member or index access. Convert with
`bytes(s)` to read its length in bytes. Strings of up to 31 bytes fit in one storage slot; longer
ones use additional slots.

## delete

`delete x` resets `x` to its default value. For a mapping entry that holds a string it clears the
stored bytes.

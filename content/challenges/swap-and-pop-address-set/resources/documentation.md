# Enumerable Sets: Background

## The problem

| structure | membership | enumerate | remove |
| --------- | ---------- | --------- | ------ |
| `mapping(address => bool)` | O(1) | impossible | O(1) |
| `address[]` | O(n) scan | yes | O(n) scan + shift |
| array + index mapping | O(1) | yes | O(1) |

Loops over storage are expensive and, when the size is controlled by users, can grow until a
transaction no longer fits in a block. The combined structure avoids them.

## Swap-and-pop

Removing from the middle of an array normally means shifting every later element. If order does not
matter, it is enough to overwrite the removed element with the last one and drop the last slot:

```
[A, B, C, D]  remove B
[A, D, C, D]  copy last into B's position
[A, D, C]     pop
```

The index mapping must be updated for the element that moved.

## The zero default

Mappings return `0` for unknown keys, and `0` is also a valid array position. Storing the position
plus one separates "at position 0" from "not present". The same trick applies to any index mapping.

## Array members

- `push(x)` appends and increases `length`.
- `pop()` removes the last element and decreases `length`; it reverts on an empty array.
- `delete arr[i]` only zeroes the element and does not change `length`.

## Returning the whole set

`values()` copies the array to memory. That is fine for off-chain reads. Calling it from another
contract on a large set can exceed the block gas limit, so on-chain consumers should use `length()`
and `at(index)` in bounded pages.

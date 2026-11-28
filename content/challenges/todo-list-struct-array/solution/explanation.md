# Reference Solution Explanation

- **Data model**: `mapping(address => Todo[])` gives each account a dynamic array of structs. Items
  are only appended, so an index is a stable identifier.
- **Returned index**: the new item's index is the array length before `push`.
- **Explicit bounds check**: `list[index]` on an invalid index reverts with `Panic(0x32)`. The
  required behaviour is a descriptive custom error, so the length is compared first.
- **Storage reference**: `Todo storage item = list[index]` points at the stored struct. Assigning
  to `item.done` writes to storage. Declaring it `memory` would copy the struct (including the
  whole string) and the write would be lost.
- **Running counter**: `doneCount` is adjusted on each toggle. Computing it with a loop in a view
  would cost more as the list grows.

## Pitfalls

- Copying the struct to memory before changing it.
- Using the wrong list length (the caller's instead of `owner`'s) in `get`.
- Incrementing `doneCount` on every toggle instead of decrementing when an item is un-done.
- Returning the length after `push` as the index, which is off by one.

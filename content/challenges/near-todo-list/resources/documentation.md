# Background: nested data with flat storage

- NEAR contract storage is a flat key-value store. Nested structures such as "a list per account" are modelled by building composite keys, or by giving each account its own prefixed collection.
- `LookupMap` returns a copy of the stored value. Changes to that object are not saved until you call `set` again with the same key.
- NEAR account ids consist of lowercase letters, digits, and the separators `-`, `_` and `.`. A character outside that set, such as `:`, is a safe delimiter for composite keys.
- Derived values such as "number of pending tasks" are cheapest when they are stored and updated on every change instead of being recomputed by scanning.

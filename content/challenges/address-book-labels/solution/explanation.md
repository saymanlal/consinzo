# Reference Solution Explanation

- **Nested mapping**: `_labels[owner][account]` gives every caller a separate book with no extra
  bookkeeping. Writes always use `msg.sender` as the first key, so one account cannot write into
  another account's book.
- **Existence check**: a mapping returns the default value for unknown keys. Since `setLabel`
  rejects empty labels, `bytes(label).length != 0` is a reliable "entry exists" test and no separate
  `bool` mapping is needed.
- **Counting**: `entryCount` is increased only when the entry did not exist before the write and
  decreased on removal. The existence check happens before the write in `setLabel`; doing it after
  would always see a stored label.
- **delete**: `delete _labels[owner][account]` resets the string to empty and frees its storage
  slots.

## Pitfalls

- Treating `getLabel` on a missing entry as a successful call that returns `""`.
- Incrementing `entryCount` on every `setLabel`, which drifts as soon as a label is overwritten.
- Allowing empty labels, which makes a stored entry indistinguishable from a missing one.
- Using the `owner` argument, rather than `msg.sender`, as the key in the write functions.

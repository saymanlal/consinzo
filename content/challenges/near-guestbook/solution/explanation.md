# Solution Explanation: NEAR Guestbook

1. **Append-only log on a LookupMap.** `LookupMap` offers key lookups only, so the contract keeps a `count` and stores message `i` under the key `String(i)`. The counter is both the next index and the total.
2. **Validate before writing.** The length check runs first, so a rejected call leaves `count` and the map untouched and the next valid message still receives the next index.
3. **Caller and time come from the runtime.** `near.predecessorAccountId()` is the account that called the contract and `near.blockTimestamp()` is the block time in nanoseconds. Neither is taken from arguments, so a caller cannot forge them.
4. **`latest(n)`** walks from `count - 1` downwards and stops when it has `n` entries or runs out of messages. Bounding the loop by both conditions gives the truncation behaviour for free.

## Pitfalls
- Returning messages oldest first, or returning `n` entries padded with `null`.
- Incrementing the counter before validation, which burns an index on a failed call.
- Accepting negative or fractional `n`.

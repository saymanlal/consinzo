# Solution Explanation: NEAR Per-Account Todo List

1. **Composite keys.** One `LookupMap<Task>` holds every task under `account + ":" + id`. NEAR account ids cannot contain `:`, so two different (account, id) pairs never produce the same key.
2. **Per-account counters.** `counts` gives each account its own id sequence and tells `listTasks` how far to iterate. `pending` is maintained incrementally so `pendingCount` does not need to scan.
3. **Caller-scoped writes.** `addTask` and `completeTask` build the key from `near.predecessorAccountId()`. An id that exists only in another account's list resolves to a missing key and fails with `Task not found`.
4. **Explicit state transition.** `completeTask` checks existence, then the `done` flag, and only then writes the updated task and decrements the pending counter. A second completion cannot decrement twice.

## Pitfalls
- A single global id counter, which breaks per-account numbering.
- Mutating the object returned by `get` without calling `set`; on a real chain the change would not be persisted.
- Decrementing the pending counter when the task was already done.

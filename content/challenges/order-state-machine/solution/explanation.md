# Reference Solution Explanation

- **Enum with a `None` member**: enums are stored as small integers and unset storage reads as `0`.
  Putting `None` first means `statusOf` of an unknown id is `None` and "order exists" is the same
  test as `status != None`.
- **One transition function**: `_advance` takes the expected current state and the next state. All
  three public transitions share it, so the check order (existence, caller, state) is defined once
  and cannot drift between functions.
- **Strict equality on the current state**: `current != expected` rejects skipping forward,
  repeating a step and moving backwards with a single comparison. `Delivered` is final simply
  because no transition expects it.
- **Sequential ids**: `id = ++orderCount` starts at 1, which keeps id `0` permanently unused.

## Pitfalls

- Using `>=`/`<=` comparisons on the enum, which lets callers skip states.
- Checking only the caller's role in general (any buyer) instead of the buyer of that specific
  order.
- Returning the first real state for unknown ids because the enum has no neutral zero member.
- Performing the state check before the caller check, which contradicts the specified error
  priority.

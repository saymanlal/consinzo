# Time Windows and Comparison Operators

`block.timestamp` is the timestamp of the current block in seconds. Blocks do not arrive
every second, and validators have some freedom in choosing the value, so contract logic
must treat time as ranges, never as exact instants.

## Half-open intervals

The cleanest way to describe a phase is a half-open interval `[start, end)`:

```
open   : start <= t <  end
closed :          t >= end
```

Each timestamp belongs to exactly one phase, and consecutive phases share no instant.
Write the rule down first, then derive every check from it:

| Rule | Check that reverts |
| --- | --- |
| allowed while `t < deadline` | `if (block.timestamp >= deadline) revert` |
| allowed once `t >= deadline` | `if (block.timestamp < deadline) revert` |

## Common mistakes

- Equality (`==`, `!=`) on timestamps.
- Mixing `<` in one function with `<=` in its counterpart, which creates an instant where
  both or neither are allowed.
- Recomputing the boundary in several places. Keep one helper and reuse it.

## Testing

For every deadline test `deadline - 1`, `deadline` and `deadline + 1`, and one value far
in the future.

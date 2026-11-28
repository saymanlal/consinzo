# Reference Solution Explanation

- **Incremental aggregation**: four numbers (`count`, `sum`, `_min`, `_max`) summarise the whole
  history. Each submission costs the same amount of gas no matter how many came before, and the
  views do no looping.
- **First submission**: when `count == 0` the value is written to both `_min` and `_max`. Storage
  is zero-initialised, so a plain `if (value < _min)` would never fire for non-zero inputs and the
  minimum would be reported as `0`. Initialising `_min` to `type(uint256).max` in a constructor is
  an equally valid approach.
- **Empty state**: the `hasData` modifier makes `min`, `max` and `average` revert with `NoData()`.
  Returning `0` would be indistinguishable from real data, and `sum / count` would revert with a
  division-by-zero panic rather than a meaningful error.
- **Average**: `sum / count` truncates, which is the specified rounding.
- **Batch**: `submitBatch` calls the same internal function per element, so both entry points
  cannot diverge.

## Pitfalls

- Using a `bool initialised` flag is fine, but `count == 0` already carries that information.
- Using `value == 0` or `_min == 0` as the "unset" marker, which breaks when `0` is submitted.
- Storing all values in an array and looping in the views: gas grows without bound.
- Wrapping the sum in `unchecked`, which would silently wrap around on overflow.

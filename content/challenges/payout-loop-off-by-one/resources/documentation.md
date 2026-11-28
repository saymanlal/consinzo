# Loop Bounds and Off-by-One Errors

An array of length `n` has valid indexes `0` to `n - 1`. The standard loop is

```solidity
for (uint256 i = 0; i < n; i++) { ... }
```

It runs exactly `n` times. Variations are where bugs come from:

| Bound | Indexes visited | Result |
| --- | --- | --- |
| `i < n` | `0 .. n-1` | correct |
| `i <= n - 1` | `0 .. n-1` | correct, but underflows when `n == 0` |
| `i < n - 1` | `0 .. n-2` | skips the last element |
| `i <= n` | `0 .. n` | out-of-bounds panic |

## Why they survive testing

Off-by-one errors often pass a casual test because the total looks plausible or because
later code hides the gap. Test the boundaries directly: zero elements, one element, two
elements, and assert on the last element specifically.

## Batch payments

Paying many addresses in one loop makes the whole batch depend on every recipient: one
reverting recipient blocks all of them, and the gas cost grows with the list. It is
acceptable for short, owner-curated lists. For open-ended lists use pull payments, where
each recipient withdraws their own amount.

# Function Visibility

Every Solidity function has one of four visibilities.

| Visibility | Callable from outside | Callable from this contract | Callable from derived contracts |
| --- | --- | --- | --- |
| `external` | yes | only via `this.f()` | only via `this.f()` |
| `public` | yes | yes | yes |
| `internal` | no | yes | yes |
| `private` | no | yes | no |

Only `external` and `public` functions appear in the ABI. An `internal` or `private`
function has no selector, and calldata that names it is treated like a call to an unknown
function: it reverts unless the contract has a fallback.

## Helpers and guards

A common structure is a guarded external function that validates the caller and then calls
an unguarded internal helper that performs the state change. The structure is safe only
when the helper is unreachable from outside. When reviewing a contract:

1. List every `public` and `external` function. That list is the complete attack surface.
2. For each helper that writes privileged state, confirm it is `internal` or `private`.
3. Treat naming conventions such as a leading underscore as documentation, never as
   enforcement.

Since Solidity 0.5.0 visibility must be written explicitly, so this bug now comes from
choosing the wrong keyword rather than from omitting one.

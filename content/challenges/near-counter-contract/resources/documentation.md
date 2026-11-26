# NEAR Contract Context & Access Control

- `near.predecessorAccountId()` identifies the immediate caller (either an EOA or an upstream cross-contract caller) and is the canonical account to check for authorization on NEAR.
- Always reject invalid step sizes (`<= 0`, non-integers, or above `maxStep`) before mutating state.

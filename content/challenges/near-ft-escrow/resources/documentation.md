# NEAR Attached Deposit & Timelock Patterns

- `near.attachedDeposit()` returns a `bigint` denominated in yoctoNEAR ($10^{-24}$ NEAR).
- `near.blockTimestamp()` returns nanosecond timestamps as `bigint`.
- Use explicit finite state values (`"OPEN" | "RELEASED" | "REFUNDED"`) to prevent duplicate settlement.

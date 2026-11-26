# Solution Explanation: NEAR Timelocked Escrow

1. **Deposit & Uniqueness Validation**: Rejects zero attached deposits, self-escrows, and duplicate escrow IDs.
2. **State Machine Safety**: `release()` and `refund()` transition `status` from `"OPEN"` to `"RELEASED"` or `"REFUNDED"` and persist to `LookupMap` so subsequent settlement attempts revert immediately.
3. **Asymmetric Timelock Rules**: Beneficiaries may claim at `blockTimestamp >= releaseAfterNs`, while depositors may only refund strictly before maturity (`blockTimestamp < releaseAfterNs`) unless the beneficiary voluntarily refunds.

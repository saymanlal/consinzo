# Solution Explanation: NEAR Predecessor Attribution

Replacing `near.signerAccountId()` with `near.predecessorAccountId()` across `setPaused()`, `deposit()`, and `withdraw()` prevents intermediate relay contracts from impersonating the transaction's originating signer.

# Reference Solution Explanation
Enforces `MIN_DELAY` when queuing, checks `[eta, eta + GRACE_PERIOD]` at execution time, and deletes `queued[txHash]` prior to invoking the target contract.

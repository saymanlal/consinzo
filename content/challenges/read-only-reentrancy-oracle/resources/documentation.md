# Protect View Price Queries Against Read-Only Reentrancy

Updates `shares` and `totalShares` before transferring ETH and enforces `require(locked == 1)` inside `sharePrice()` so external consumers cannot observe stale mid-tx invariants.

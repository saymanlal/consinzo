# Protect View Queries Against Read-Only Reentrancy

During `withdraw()`, `PoolViewGuard` sends ETH before burning `totalShares` and exposes `sharePrice()` without checking reentrancy lock status.

## Objective
1. Burn shares and update state **before** the ETH transfer.
2. Also reject `sharePrice()` reads while `locked == 2`.
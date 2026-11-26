# Linear Token Vesting Wallet with Cliff

Implement `vestedAmount(uint256 timestamp)` and `release()` returning 0 before `cliff`, linear fraction between `start` and `start + duration`, and 100% after `start + duration`.
# Reference Solution Explanation

- **Two entry points, one path**: `receive()` runs for calls with empty calldata and `tip()` for the
  named call. Both delegate to `_recordTip`, so a plain transfer is credited exactly like an
  explicit tip.
- **Lifetime statistics**: `tipsOf`, `totalTips` and `tipperCount` describe what was given, not
  what is currently held. `withdraw` reads `address(this).balance` and leaves the statistics alone.
- **Distinct tippers**: zero tips are rejected, so `tipsOf[msg.sender] == 0` is true exactly on an
  address's first tip.
- **Withdrawal**: authorization first, then the empty check, then the transfer with
  `call{value: ...}("")`, whose success flag is checked. `transfer`/`send` forward only 2300 gas and
  can fail for contract owners.
- **Reentrancy**: `withdraw` sends the full balance to the owner and updates nothing afterwards. A
  re-entrant call by the owner finds an empty balance and reverts, so there is nothing to exploit.

## Pitfalls

- Implementing only `tip()` and forgetting `receive()`, which makes plain transfers revert.
- A `receive()` that accepts the ETH but does not record it.
- Resetting `totalTips` on withdrawal, or withdrawing `totalTips` instead of the balance, which
  fails on the second withdrawal.
- Ignoring the boolean returned by `call`.

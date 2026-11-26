# Reference Solution Explanation

- **Access Control**: `mint` enforces `msg.sender == owner` and rejects `address(0)` recipients.
- **Unchecked Arithmetic Safety**: Balances and allowances are explicitly checked with `require` before subtracting inside `unchecked` blocks to save gas safely in Solidity 0.8+.
- **Infinite Approvals**: When `allowance[from][msg.sender] == type(uint256).max`, the storage write is skipped per EIP-20 ecosystem convention (Solmate / OpenZeppelin).

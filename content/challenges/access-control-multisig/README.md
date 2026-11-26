# Multi-Signature Treasury Wallet

Build `MultisigWallet` with configurable `owners` and `requiredConfirmations`.

## Requirements
- Validate non-empty unique non-zero owners and `1 <= required <= owners.length` in constructor.
- `submitTransaction(address to, uint256 value, bytes calldata data)` (onlyOwner) creates a proposal and returns `txId`.
- `confirmTransaction(uint256 txId)` (onlyOwner) records confirmation once per owner.
- `revokeConfirmation(uint256 txId)` (onlyOwner) removes a prior confirmation before execution.
- `executeTransaction(uint256 txId)` (onlyOwner) executes once `confirmations >= required` and marks `executed = true` before the external call.

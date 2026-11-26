# Handle Fee-on-Transfer Tokens

`FeeSafeVault.deposit(amount)` credits `balances[msg.sender] += amount`, even when the token deducts a 5% transfer fee.

## Objective
Measure `token.balanceOf(address(this))` before and after `transferFrom` and credit the exact delta received.
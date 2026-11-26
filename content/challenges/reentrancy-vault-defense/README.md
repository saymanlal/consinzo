# Patch Reentrancy in an ETH Savings Vault

`VulnerableVault` allows users to deposit and withdraw ETH, but updates `balances[msg.sender]` **after** transferring ETH.

## Security Objective
1. Preserve legitimate `deposit()` and `withdraw()` behavior.
2. Eliminate the reentrancy vulnerability so an attacker contract calling `withdraw()` from `receive()` cannot drain other users' funds.

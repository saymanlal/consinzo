# Exploit Cross-Function Reentrancy

`CrossBank` lacks a mutex across `withdraw()` and `transferBalance(to, amount)` and sets `balances[msg.sender] = 0` after the external ETH call in `withdraw()`.

## Objective
Implement `CrossExploit.attack()` to double-credit `accomplice` and drain more ETH than deposited.
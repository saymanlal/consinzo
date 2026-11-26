# Exploit Cross-Function Reentrancy in Bank Contract

Deposits `msg.value`, calls `withdraw()`, and inside `receive()` shifts `balances[address(this)]` to `accomplice` before `withdraw()` clears `balances[address(this)]`.

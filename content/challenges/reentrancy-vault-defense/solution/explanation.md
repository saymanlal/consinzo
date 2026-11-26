# Reference Solution Explanation
Applies Checks-Effects-Interactions (`balances[msg.sender] = 0` before `.call`) combined with a `nonReentrant` mutex lock (`locked = 1 / 2`) so both reverting and `try/catch`-wrapped reentrancy attempts cannot drain funds.

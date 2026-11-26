# Eliminate Weak On-Chain Randomness & Revert-on-Loss

Removes single-tx `play()` and enforces `block.number > commitBlock[msg.sender]` plus commitment preimage verification.

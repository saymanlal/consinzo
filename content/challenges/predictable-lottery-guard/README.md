# Eliminate Weak On-Chain Randomness

`CommitRaffle.play()` resolves immediately using `block.timestamp`, allowing a contract to revert whenever it does not win.

## Objective
Require `commit(bytes32 commitment)` in one block/timestamp and `reveal(uint256 secret)` in a strictly later block.
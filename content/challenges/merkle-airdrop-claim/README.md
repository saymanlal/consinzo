# Gas-Efficient Merkle Airdrop Distributor

Implement `MerkleAirdrop` verifying inclusion against `merkleRoot` and preventing double claims.

## Requirements
- Leaf hash: `keccak256(abi.encodePacked(index, account, amount))`.
- Sorted-pair node hashing: `a <= b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a))`.
- Track `claimed[index]` (or bitmap) and mark claimed before sending ETH.

# Why the patch works

The starter computes the commitment as `keccak256(abi.encode(amount, salt))`. A commitment is
public the moment it is stored, and the preimage becomes public the moment the honest
bidder broadcasts `reveal`. Because the preimage does not name the bidder, the same
`(amount, salt)` opens the copied commitment for the copier. With "first reveal wins a tie",
a front-run reveal steals the winning position without the attacker ever knowing the bid in
advance.

The reference changes one line:

```solidity
return keccak256(abi.encode(address(this), bidder, amount, salt));
```

`reveal` already calls `computeCommitment(msg.sender, amount, salt)`, so the stored hash now
only matches when the caller is the account named in the preimage. A copier would need a
preimage that contains their own address, which the honest bidder never produced.

## Pitfalls

- Storing commitments per `msg.sender` is not enough. The starter already does that; the
  weakness is in what the hash covers, not in where it is stored.
- Use `abi.encode`, not `abi.encodePacked`, so field boundaries cannot be shifted.
- Include `address(this)`. Without it a commitment made for one auction opens in every other
  deployment of the same contract.
- Rejecting duplicate commitment hashes looks like a fix but is a denial of service: an
  attacker front-runs the honest `commit` with the same hash and locks the honest bidder out.

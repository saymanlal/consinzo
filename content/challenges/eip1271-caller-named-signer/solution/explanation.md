# Why the patch works

EIP-1271 lets a contract say "I accept this hash". The statement is only as meaningful as the
identity of the contract making it. In the starter the relayer supplies that identity, so
the vault effectively asks the attacker's contract whether the attacker may take the money.

## Authorisation before validation

The reference adds one condition before the signature query:

```solidity
if (signer != w.account && !isDelegate[w.account][signer]) revert UnauthorizedSigner();
```

Authority now starts at the account whose balance is debited. Either the account answers
for itself, or it has registered the signer through `setDelegate`, which is keyed by
`msg.sender` and therefore cannot be set by anyone else. Another honest wallet approving the
same hash, or a signer registered by a different account, fails this check.

## A hardened EIP-1271 query

The signer is still a foreign contract. The reference queries it with a low-level
`staticcall` and accepts only a successful call returning at least 32 bytes whose first word
equals the left-aligned magic value. Consequences:

- a reverting signer produces `InvalidSignature()` rather than its own error;
- four raw bytes, or the magic value in the wrong position, are rejected;
- an address without code returns empty data and is rejected (a high-level call would
  revert on the code-size check instead);
- `staticcall` guarantees the signer cannot re-enter and change state during validation.

## Pitfalls

- Dropping the `signer` parameter and always asking `w.account` fixes the theft but removes
  the delegate feature the interface promises.
- Checking `isDelegate[signer][w.account]` (arguments swapped) lets the attacker's contract
  "register" the victim.
- State changes must come after validation and before the ETH transfer; the nonce increment
  is what makes an approved hash single-use.

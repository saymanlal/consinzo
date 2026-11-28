# Operation identity in governor and timelock systems

## The life of a proposal

```
propose --> vote --> queue (timelock, eta = now + delay) --> execute
```

Each arrow is a hand-off, often between two contracts. A hand-off is safe only if both sides
agree on the identity of the operation.

## What an identifier must cover

An operation is the tuple `(target, value, calldata)`, sometimes a batch of them plus a salt.
A sound identifier is a hash over all of those fields:

```solidity
bytes32 id = keccak256(abi.encode(target, value, data));
```

If any field is left out, that field is chosen by whoever supplies it later. Typical
mistakes:

| Identifier used | What the executor can change |
| --- | --- |
| sequential proposal number | everything |
| hash of description text | everything |
| hash of target and calldata | ETH value |
| hash of calldata only | target contract |

## Why payloads are re-supplied at execution

Storing calldata costs 20 000 gas per 32 bytes. Many governors therefore store only the hash
and ask the executor to provide the preimage. This is safe when the hash is checked, and
catastrophic when it is not, because execution is usually permissionless.

## Defence in depth

The timelock is the account that owns funds and privileged roles. Its `execute` should
verify the operation against what *it* recorded at queue time, independently of the
governor. Then a bug or upgrade in the governor cannot widen what the timelock will run.

## Checklist

- Commit to the full payload before voting starts.
- Use `abi.encode` for the commitment.
- Verify the commitment in every function that takes the payload as an argument.
- Mark operations done before the external call and revert on failure.

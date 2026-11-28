# Access Control on State-Changing Functions

A function marked `external` or `public` can be called by any account or contract. The
compiler does not know which functions are meant to be privileged, so every function that
creates value (minting, withdrawing, changing configuration) needs an explicit check.

## The owner pattern

```solidity
modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner();
    _;
}
```

- Store the privileged address in storage so it can be handed over.
- Compare against `msg.sender`, the immediate caller. `tx.origin` is the externally owned
  account that started the transaction and must not be used for authorisation.
- Revert with a custom error. It costs less gas than a string and gives tests and
  front ends a stable selector to match.

## Reviewing for missing checks

List every `external` and `public` function that writes storage or moves funds, and for
each one write down who is allowed to call it. Any function where the answer is not
"anyone" must contain a check that enforces that answer.

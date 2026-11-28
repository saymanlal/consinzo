# Constants and Immutables

## Three kinds of state variable

| Kind | Assigned | Stored in | Read cost |
| --- | --- | --- | --- |
| regular | any time | a storage slot | `SLOAD` (2,100 gas cold) |
| `constant` | at declaration, from a compile-time expression | nowhere; inlined | a `PUSH` |
| `immutable` | at declaration or in the constructor | the runtime bytecode | a `PUSH` |

A `constant` must be computable by the compiler, so it cannot depend on `block.timestamp`,
`msg.sender` or a constructor argument. An `immutable` can, because it is fixed when the
constructor runs.

## Rules for immutables

- They can be assigned only while the contract is being constructed.
- Once the constructor returns, the value is part of the deployed code and cannot change.
- Public immutables and constants get an automatic getter, just like storage variables.

## Basis points

A basis point is one hundredth of a percent, so 10,000 basis points are 100%. Fees are expressed
in basis points because Solidity has no fractional numbers:

```
fee = amount * feeBps / 10_000
```

Integer division truncates. Always multiply first, and derive the remainder by subtraction rather
than by a second division, so that the parts add up to the whole.

## Reverting from a constructor

A constructor that reverts leaves no contract behind. Custom errors work in constructors exactly
as they do in functions, and the creating contract can inspect the revert data with `try new`.

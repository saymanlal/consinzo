# Function Modifiers and the Pause Pattern: Background

## Modifiers

A modifier is reusable code wrapped around a function body:

```solidity
modifier whenNotPaused() {
    if (paused) revert EnforcedPause();
    _;
}

function ping() external whenNotPaused { ... }
```

The `_;` statement is replaced by the function body (or by the next modifier). Statements before
`_;` run before the body and statements after it run afterwards. Several modifiers on one function
are applied from left to right, so the leftmost check fails first.

## The pause pattern

A pause switch is a circuit breaker. When something goes wrong, an authorised account stops the
functions that move value or change important state, which buys time to investigate. Typical
design:

- user-facing functions carry `whenNotPaused`;
- recovery functions carry `whenPaused`, so they cannot interfere with normal operation;
- `pause`/`unpause` are restricted and guarded by the same modifiers so they cannot be repeated.

## Trade-off

Whoever controls the switch can freeze the contract. Real systems limit that power, for example
with a multisig owner, an automatic expiry of the pause, or by leaving withdrawals unpausable.

## bool defaults

A `bool` state variable starts as `false`, so a contract with `bool public paused;` starts running
without any constructor code.

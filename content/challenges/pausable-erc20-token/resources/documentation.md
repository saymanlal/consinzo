# Pausable Tokens

## Purpose

A pause (also called an emergency stop or circuit breaker) lets a privileged account stop
selected functions when a vulnerability or compromise is discovered, buying time to respond.
It is a centralisation trade-off: holders must trust the pauser not to freeze the token
arbitrarily.

## Implementing the gate

The usual pattern is a boolean flag plus a modifier:

```solidity
modifier whenNotPaused() {
    if (paused) revert EnforcedPause();
    _;
}
```

A modifier runs its code before the function body (at the `_` placeholder), which makes the
ordering of checks explicit. An internal function called at the top of the body is equivalent.

## Scope of a pause

For every external function decide which of these it is:

- **Moves value between users** (`transfer`, `transferFrom`): normally blocked.
- **Changes supply** (`mint`, `burn`): depends on the recovery plan; state the rule.
- **Changes permissions only** (`approve`): usually left open so approvals can be revoked.
- **Read-only**: never blocked.

## ERC-20 reminder

`transferFrom(from, to, amount)` spends `allowance[from][msg.sender]`. It is a second route by
which tokens move, so any restriction on `transfer` must be applied to it as well.

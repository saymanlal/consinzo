# Compound authorisation checks

## Negated guards and De Morgan's laws

Solidity guards are usually written as "revert if the caller is not allowed". When the
permission is a compound condition, the negation has to be distributed correctly:

```
!(A && B)  ==  !A || !B      // "both required"  -> revert if either is missing
!(A || B)  ==  !A && !B      // "either suffices" -> revert only if both are missing
```

Using `&&` between two negated role checks therefore implements "either role suffices".
This compiles, passes a happy-path test with a fully privileged account, and silently
downgrades dual control to single control.

## Practical habits

- Express the permission positively in one helper (`_hasBoth`, `_isOperatorOrOwner`) and
  negate the helper as a whole.
- Test the full truth table. For two roles that is four callers per function: none, only A,
  only B, both. Add the owner if the owner has a separate path.
- Keep "who may stop the system" and "who may restart it" as separate decisions. A lower bar
  for stopping is common; the same bar for restarting usually is not.
- Order checks so that authorisation is evaluated before any state-dependent check.

## Why it matters

Dual control (also called the four-eyes principle or separation of duties) exists so that
one stolen or misused key is not enough to move funds. A guard that accepts a single role
removes that property without any visible change in normal operation.

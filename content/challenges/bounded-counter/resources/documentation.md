# Bounded Arithmetic: Background

## Checked arithmetic in Solidity 0.8

Since 0.8.0 every `+`, `-` and `*` on integers reverts with `Panic(0x11)` when the result does not
fit the type. That protects the type range only. A business rule such as "never above `max`" still
needs its own check and its own error.

## Check the room, not the sum

To test whether `a + b` exceeds a limit `L` when `a <= L` is already known, compare `b` with the
room that is left:

```solidity
if (b > L - a) revert TooLarge();
```

`L - a` cannot underflow, and nothing is added before the check, so no input can cause a panic.

## unchecked blocks

Inside `unchecked { ... }` the compiler omits overflow checks. Use it only where an earlier check
already proves the operation is safe.

## Immutables

`min` and `max` never change after deployment. Declaring them `immutable` stores them in the
contract code instead of storage, which makes every read cheaper.

## Custom errors with arguments

`revert AboveMax(max)` encodes the selector plus the argument. A caller can decode the limit it
ran into without an extra call.

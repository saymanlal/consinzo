# Dead-Man Switches: Background

## The idea

A dead-man switch triggers when its operator stops performing a routine action. On-chain it is
used for inheritance and key-loss recovery: the owner of a wallet periodically proves liveness, and
if the proofs stop for long enough, a backup address gains control.

## Liveness as a timestamp

Contracts cannot run on a timer. Nothing happens "when the period elapses"; state only changes when
someone sends a transaction. The usual design therefore stores the time of the last proof of life
and lets the backup party call a function that checks, at call time, whether enough time has
passed:

```
claim allowed  <=>  block.timestamp >= lastHeartbeat + silencePeriod
```

Consequences worth understanding:

- Until the heir actually claims, the owner can still reset the timer, even if they were silent for
  longer than the period.
- `block.timestamp` is set by the block proposer and can be nudged by a few seconds. Periods of
  days or weeks are not meaningfully affected.

## Access control by stored address

Owner-only functions compare `msg.sender` to a stored `owner`. Handing over the wallet is then a
single storage write: once `owner` changes, the previous owner fails every check. Use `msg.sender`
for these checks, never `tx.origin`.

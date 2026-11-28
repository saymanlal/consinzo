# Reference Solution Explanation

## The trust model

`checkUpkeep` is a simulation. Its output is a suggestion that reaches `performUpkeep`
later, possibly after other transactions, and `performUpkeep` has no access control, so
anyone can submit any bytes. The only safe design is to treat `performData` as a list of
candidate ids and to decide from current storage whether each one may run. The reference
uses the same `isDue` predicate in both functions so the two can never disagree.

## performUpkeep

- **Skip, do not revert, on ids that are not due.** If one stale id reverted the batch, a
  task owner could cancel a task between simulation and execution and block every other
  task in the batch.
- **Revert when nothing ran.** A keeper should not pay for a transaction that did nothing,
  and a revert makes the problem visible in simulation.
- **Effects before the call.** `runs` and `nextRunAt` are written before the target is
  called. After that the task is not due, which handles two cases with one mechanism: a
  duplicate id later in the array, and a target that calls back into `performUpkeep`. The
  nested call finds nothing due and reverts with `NothingDue()`.
- **Failure isolation.** The target is called with a low-level `call` and the result is
  recorded in `failures`. The task is still rescheduled, so a permanently failing task
  costs one call per interval rather than one call per block.

## Rescheduling

`nextRunAt += interval * (missed + 1)` with `missed = (now - nextRunAt) / interval` keeps
the task on its original grid (`firstRunAt + k * interval`) and lands on the first slot
strictly after `now`. Setting `nextRunAt = now + interval` drifts; adding a single
`interval` after a long outage leaves the task due again immediately and replays every
missed slot.

## checkUpkeep

Memory arrays cannot grow, so due ids are written to a buffer of `maxBatch` entries and
copied into an exactly sized array. The loop stops at `maxBatch` hits, which bounds the
work `performUpkeep` will be asked to do. The optional `(lo, hi)` range lets several
upkeeps share one scheduler without scanning the same ids.

## Pitfalls

- Trusting `performData` because "it came from `checkUpkeep`".
- Calling the target before updating `nextRunAt`.
- Using `require(success)` on the target call.
- Returning an array padded with zeros instead of one with the exact length.

A production scheduler would also cap the gas forwarded to each target so that one task
cannot consume the whole transaction; that is outside the scope of this exercise.

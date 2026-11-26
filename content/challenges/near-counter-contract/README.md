# NEAR Stateful Counter & Access Control

## Objective
Implement `Counter` in TypeScript (`src/Counter.ts`) targeting the NEAR deterministic runtime (`near-sdk-js`).

## Specification
1. Constructor `new Counter(maxStep: number)` initializes:
   - `owner` to `near.predecessorAccountId()`
   - `maxStep` (must be a positive integer `>= 1`)
   - `value = 0`, `lastCaller = ""`
2. `increment(by = 1): number`:
   - Require integer `by` with `1 <= by <= maxStep`.
   - Increase `value` by `by`, set `lastCaller = near.predecessorAccountId()`, and return new `value`.
3. `decrement(by = 1): number`:
   - Require integer `by` with `1 <= by <= maxStep` and `value >= by`.
   - Decrease `value` by `by`, set `lastCaller = near.predecessorAccountId()`, and return new `value`.
4. `reset(): void`:
   - Only `owner` (`near.predecessorAccountId() === this.owner`) may call `reset()`.
   - Sets `value = 0` and updates `lastCaller`.
5. View helpers: `getValue(): number`, `getOwner(): string`, `getLastCaller(): string`.

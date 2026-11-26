# Solution Explanation: NEAR Stateful Counter

1. **Access Control**: `reset()` checks `near.predecessorAccountId() === this.owner` instead of `signerAccountId()`, preventing confused-deputy attacks across cross-contract calls.
2. **Input & Arithmetic Guards**: Both `increment` and `decrement` enforce integer step bounds `1 <= by <= maxStep`, and `decrement` verifies `this.value >= by` before mutating state.

# Cross-contract reentrancy

## Beyond the single-contract picture

The textbook reentrancy bug re-enters the same function. A reentrancy lock on that function
fixes it, and a lock shared by all functions of the contract fixes the cross-function
variant. Neither helps when the inconsistent state is consulted or acted on by a *second*
contract:

1. Contract A makes an external call while some of its state is stale.
2. The callee calls contract B.
3. Contract B, which trusts A (or is trusted by A), calls back into A through a privileged
   hook, or reads A's stale state.

A's lock may not be held on that path, and B's lock knows nothing about A.

## Why systems end up here

Protocols are split into vaults, gauges, distributors, strategies and routers that call each
other through hooks. Hooks are commonly exempt from locks because "only our own contract can
call them". The exemption is correct about *who* calls and wrong about *when*: the trusted
contract can be made to call at a moment chosen by an attacker.

## Defences

- **Checks-effects-interactions everywhere.** If every function finishes its own bookkeeping
  before making an external call, there is no stale state for anyone to find. This is the
  only defence that does not depend on knowing every call path.
- **System-wide locks.** A single lock contract consulted by all components, when ordering
  alone cannot be guaranteed.
- **Pull payments.** Credit rewards to a balance and let users withdraw them separately, so
  bookkeeping functions make no external calls.

## Reward-per-share accounting in one paragraph

`acc` accumulates reward per staked unit. A user's entitlement is `stake * acc - debt`,
where `debt` is set to `stake * acc` whenever the user is paid or their stake changes.
Paying without updating `debt` means the same entitlement can be computed again.

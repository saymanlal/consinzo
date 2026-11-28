# Sending ETH and Checking the Result

Solidity offers three ways to send ETH from a contract.

| Call | Gas forwarded | On failure |
| --- | --- | --- |
| `payable(a).transfer(x)` | 2300 | reverts |
| `payable(a).send(x)` | 2300 | returns `false` |
| `a.call{value: x}("")` | all remaining gas | returns `false` |

Two of the three do not revert. Whenever a low-level call or `send` is used, the returned
`bool` has to be checked, otherwise the contract continues with bookkeeping that no longer
matches reality.

## Why not `transfer`

The 2300 gas stipend is enough to emit one event and nothing else. Smart contract wallets,
multisigs and proxies routinely need more, and gas costs of opcodes have changed between
hard forks. The current recommendation is `call` with a checked result, combined with the
checks-effects-interactions order.

## Checks, effects, interactions

1. Checks: validate the caller and the amount.
2. Effects: update storage (for example, zero the balance).
3. Interactions: make the external call and revert if it failed.

A revert in step 3 rolls back the effects of step 2 automatically.

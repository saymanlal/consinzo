# Enforce Slippage & Deadline Bounds Against Sandwich MEV

`SwapRouterGuard.swapExactIn` ignores `minAmountOut` and `deadline`, letting an MEV searcher sandwich the transaction and deliver near-zero tokens.

## Objective
Enforce `block.timestamp <= deadline`, `minAmountOut > 0`, and `amountOut >= minAmountOut`.
# Enforce Slippage & Deadline Bounds Against Sandwich MEV

Checks transaction expiry against `block.timestamp`, rejects zero slippage bounds, and verifies `amountOut >= minAmountOut`.

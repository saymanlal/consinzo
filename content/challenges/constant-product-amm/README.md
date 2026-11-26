# Constant Product AMM Pool

Implement `SimpleAMM` managing two internal reserve balances (`reserve0`, `reserve1`) and LP `shares`.
For self-contained deterministic testing, `SimpleAMM` operates on a pair of minimal IERC20 interfaces (`token0`, `token1`).

## Requirements
- `addLiquidity(uint256 amount0, uint256 amount1)` pulls tokens and mints LP shares (`sqrt(amount0 * amount1)` on initial deposit, proportional thereafter).
- `removeLiquidity(uint256 shareAmount)` burns shares and returns proportional `amount0` and `amount1`.
- `swap(address tokenIn, uint256 amountIn)` charges a 0.3% fee (`997/1000`), transfers `amountOut` of the opposite token, and preserves `reserve0 * reserve1 >= k_before`.

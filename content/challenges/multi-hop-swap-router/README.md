# Multi-Hop Exact-Input Swap Router

## Problem Statement

Implement `SwapRouter` in `src/SwapRouter.sol`. The router works on top of existing
constant-product pairs that charge a 0.3% fee. Given an exact input amount and a path of
tokens `[t0, t1, ..., tn]`, it swaps `t0` for `t1` in the pair `(t0, t1)`, the result for `t2`
in the pair `(t1, t2)`, and so on, and delivers the final output to a recipient.

The pairs and the factory are provided (the tests deploy mocks that implement the interfaces
declared in the starter). You only write the router.

## Provided interfaces

```solidity
interface IPairFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair); // address(0) if none
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
    // Sends the requested outputs to `to`. The input must already have been transferred to
    // the pair. Reverts if the constant-product check (with the 0.3% fee) fails.
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}
```

## Interface to implement

```solidity
constructor(address factory_)

function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
    public pure returns (uint256 amountOut)
function getAmountsOut(uint256 amountIn, address[] memory path)
    public view returns (uint256[] memory amounts)
function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
) external returns (uint256[] memory amounts)
```

## Rules

1. `getAmountOut` reverts with `ZeroAmount()` if `amountIn == 0` and with
   `InsufficientLiquidity()` if either reserve is zero. Otherwise

   ```
   amountInWithFee = amountIn * 997
   amountOut = amountInWithFee * reserveOut / (reserveIn * 1000 + amountInWithFee)   (rounded down)
   ```
2. `getAmountsOut(amountIn, path)` reverts with `InvalidPath()` if `path.length < 2` and with
   `PairNotFound()` if the factory has no pair for two consecutive tokens. It returns an array
   of `path.length` elements: `amounts[0] = amountIn` and `amounts[i + 1]` is the output of hop
   `i` computed with `getAmountOut` on that pair's current reserves, oriented correctly for the
   direction of the hop.
3. `swapExactTokensForTokens`:
   - reverts with `Expired()` if `block.timestamp > deadline` (checked first);
   - computes `amounts = getAmountsOut(amountIn, path)`;
   - reverts with `InsufficientOutputAmount()` if the last amount is below `amountOutMin`;
   - transfers `amountIn` of `path[0]` from the caller directly to the first pair
     (`TransferFailed()` if the token returns `false`);
   - for each hop calls `swap` on the pair with the quoted output on the correct side and zero
     on the other; the output goes to the next pair, or to `to` for the last hop;
   - emits `Swapped(sender, to, path[0], path[path.length - 1], amountIn, amountOut)` and
     returns `amounts`.
4. The router holds no tokens before or after a swap and has no state besides `factory`.
5. Paths are expected to use each pair at most once. Behaviour for paths that revisit a pair
   is not specified and not tested.

## What the tests check

- The quote formula, including rounding, and multi-hop quotes.
- Single-hop and multi-hop swaps in both token orders, with exact output amounts.
- Minimum-output and deadline boundaries, invalid paths and missing pairs.
- That the pairs end with reserves equal to their balances and the router holds nothing.

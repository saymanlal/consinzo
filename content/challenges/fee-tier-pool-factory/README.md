# Fee Tier Pool Factory with Per-Pool Fee Accounting

## Problem Statement

Implement `PoolFactory` and `FeePool` in `src/PoolFactory.sol`.

The factory deploys at most one pool for every combination of an unordered token pair and an
enabled fee tier. Each pool is a constant-product pool whose swap fee is fixed at creation.
The fee of every swap is split: the liquidity-provider part stays in the reserves, the
protocol part is tracked in a separate per-pool balance that only the factory can collect.

`IERC20Like` is provided in the starter. All tokens used by the tests return `true` and
revert on failure.

## Units

- Fee tiers are expressed in millionths: `3000` means 0.30 %. `FEE_DENOMINATOR = 1_000_000`.
- `protocolFeeBps` is the share of each swap fee that goes to the protocol, in basis points
  of the fee (`10_000` = the whole fee). It is capped at `2_500`.
- All divisions round down.

## PoolFactory

```solidity
error NotOwner();
error InvalidFee();
error TierAlreadyEnabled();
error TierNotEnabled();
error IdenticalTokens();
error ZeroAddress();
error PoolExists();
error InvalidProtocolFee();
error UnknownPool();

event FeeTierEnabled(uint24 fee);
event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee, address pool);

constructor();                                   // owner = deployer; tiers 500, 3000, 10000 enabled
function owner() external view returns (address);
function protocolFeeBps() external view returns (uint16);   // 0 after deployment
function feeTierEnabled(uint24 fee) external view returns (bool);
function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
function isPool(address pool) external view returns (bool);
function allPools(uint256 i) external view returns (address);
function allPoolsLength() external view returns (uint256);

function enableFeeTier(uint24 fee) external;
function setProtocolFeeBps(uint16 bps) external;
function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
function collectProtocolFees(address pool, address to) external returns (uint256 amount0, uint256 amount1);
```

Rules:

1. `enableFeeTier` is owner-only (`NotOwner`). `fee` must satisfy `0 < fee < 100_000`
   (`InvalidFee`) and must not already be enabled (`TierAlreadyEnabled`). Tiers cannot be disabled.
2. `setProtocolFeeBps` is owner-only and reverts with `InvalidProtocolFee` above `2_500`.
   Pools read the current value from the factory on every swap.
3. `createPool` can be called by anyone. Checks, in this order: `IdenticalTokens` when
   `tokenA == tokenB`, `ZeroAddress` when either token is zero, `TierNotEnabled`, `PoolExists`.
   The pool is deployed with `token0 < token1` (address order). `getPool` returns the pool
   for both argument orders, `isPool[pool]` becomes true and the pool is appended to `allPools`.
4. `collectProtocolFees` is owner-only, reverts with `UnknownPool` for an address that the
   factory did not deploy, and forwards to `FeePool.collectProtocolFees(to)`.

## FeePool

```solidity
error NotFactory();
error InvalidToken();
error ZeroAmount();
error ZeroLiquidity();
error InsufficientLiquidity();
error InsufficientOutput();

constructor(address token0_, address token1_, uint24 fee_);   // factory = msg.sender

function factory() external view returns (address);
function token0() external view returns (address);
function token1() external view returns (address);
function fee() external view returns (uint24);
function reserve0() external view returns (uint256);
function reserve1() external view returns (uint256);
function totalLiquidity() external view returns (uint256);
function liquidityOf(address provider) external view returns (uint256);
function protocolFees0() external view returns (uint256);
function protocolFees1() external view returns (uint256);
function totalFees0() external view returns (uint256);   // every fee ever charged on token0 input
function totalFees1() external view returns (uint256);

function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity);
function removeLiquidity(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1);
function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut);
function collectProtocolFees(address to) external returns (uint256 amount0, uint256 amount1);
```

Rules:

1. `addLiquidity` pulls exactly `amount0` and `amount1` from the caller with `transferFrom`.
   - First deposit (`totalLiquidity == 0`): `liquidity = floor(sqrt(amount0 * amount1))`.
   - Later deposits: `liquidity = min(amount0 * totalLiquidity / reserve0, amount1 * totalLiquidity / reserve1)`.
   - Reverts with `ZeroLiquidity` when the result is `0`. Both reserves grow by the full amounts.
2. `removeLiquidity` reverts with `ZeroAmount` for `0` and `InsufficientLiquidity` when the
   caller owns less. It pays `liquidity * reserve / totalLiquidity` of each reserve to `to`.
   Protocol fees are never part of the reserves and are not paid out here.
3. `swap` (exact input), with `reserveIn` / `reserveOut` the reserves before the swap:
   - `tokenIn` must be `token0` or `token1` (`InvalidToken`); `amountIn > 0` (`ZeroAmount`).
   - `feeAmount = amountIn * fee / 1_000_000`
   - `protocolCut = feeAmount * factory.protocolFeeBps() / 10_000`
   - `netIn = amountIn - feeAmount`
   - `amountOut = netIn * reserveOut / (reserveIn + netIn)`; revert with `InsufficientOutput`
     when `amountOut < minAmountOut` or `amountOut == 0`.
   - `reserveIn += amountIn - protocolCut`, `reserveOut -= amountOut`.
   - `protocolFees` of the input token grows by `protocolCut`, `totalFees` of the input
     token grows by `feeAmount`.
   - `amountIn` is pulled from the caller, `amountOut` is sent to `to`.
4. `collectProtocolFees` can only be called by the factory (`NotFactory`). It transfers both
   protocol balances to `to`, resets them to zero and returns the amounts.

Invariant: for each token, `balanceOf(pool) == reserve + protocolFees` whenever no transfer
is in progress.

## What the Tests Check

- Tier management, pool uniqueness in both token orders, registry views.
- Exact reserve, fee and output values for swaps in both directions, with and without a protocol cut.
- That pools of different tiers for the same pair keep separate books.
- Access control on every privileged path and that protocol fees cannot leak through
  `removeLiquidity`.

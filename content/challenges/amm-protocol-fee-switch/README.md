# AMM Protocol Fee Switch with kLast Accounting

## Problem Statement

Implement `FeeSwitchPair` in `src/FeeSwitchPair.sol`: a two-token constant-product pair with
a 0.30% swap fee and a *protocol fee switch*. Traders always pay 0.30%. When the switch is on,
one sixth of the fee growth is diverted to the protocol by minting new LP shares to a fee
recipient at the next liquidity event (`mint` or `burn`). Nothing is transferred during swaps.

The file also contains `IERC20Like`, a minimal token interface. The tests deploy their own
mock tokens that revert on failed transfers.

## Required Interface

```solidity
error NotOwner();
error InvalidToken();
error ZeroAmount();
error InsufficientLiquidityMinted();
error InsufficientLiquidity();
error InsufficientOutput();

event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
event ProtocolFeeMinted(address indexed feeTo, uint256 liquidity);

uint256 public constant MINIMUM_LIQUIDITY = 1000;

constructor(address token0_, address token1_);   // owner = msg.sender

function owner() external view returns (address);
function token0() external view returns (address);
function token1() external view returns (address);
function feeTo() external view returns (address);            // address(0) means the switch is off
function reserve0() external view returns (uint256);
function reserve1() external view returns (uint256);
function kLast() external view returns (uint256);
function totalSupply() external view returns (uint256);
function balanceOf(address account) external view returns (uint256);

function setFeeTo(address newFeeTo) external;
function mint(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity);
function burn(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1);
function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut);
```

## Rules

All divisions are integer divisions that round down. `sqrt` is the integer square root
(floor).

### Reserves

The pair tracks `reserve0` and `reserve1` itself; it never reads its own token balances.
Tokens are pulled with `transferFrom(msg.sender, address(this), amount)` and paid out with
`transfer`.

### `setFeeTo`

Only `owner` (`NotOwner` otherwise). Stores the new recipient. It does not touch `kLast` or
mint anything.

### Protocol fee (`_mintFee`)

Runs at the start of every `mint` and `burn`, before reserves or supply change:

- Switch on (`feeTo != address(0)`):
  - if `kLast != 0`, let `rootK = sqrt(reserve0 * reserve1)` and `rootKLast = sqrt(kLast)`.
    If `rootK > rootKLast`, mint
    `totalSupply * (rootK - rootKLast) / (rootK * 5 + rootKLast)` shares to `feeTo`
    (skip the mint and the event if this is zero) and emit `ProtocolFeeMinted`.
  - if `kLast == 0` nothing is minted.
- Switch off: nothing is minted, and `kLast` is set to `0` if it is not already.

At the end of every `mint` and `burn`, after the reserves have been updated, set
`kLast = reserve0 * reserve1` if the switch is on. Swaps never change `kLast`.

### `mint(amount0, amount1, to)`

1. Run `_mintFee`.
2. If `totalSupply == 0`: `liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY`, and
   `MINIMUM_LIQUIDITY` shares are minted to `address(0)` permanently. Revert with
   `InsufficientLiquidityMinted` when `sqrt(amount0 * amount1) <= MINIMUM_LIQUIDITY`.
3. Otherwise `liquidity = min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)`
   using the total supply *after* step 1. Revert with `InsufficientLiquidityMinted` if zero.
4. Pull exactly `amount0` and `amount1` from the caller (no refund of an unbalanced excess),
   add them to the reserves, mint `liquidity` to `to`, update `kLast`, emit `Mint`.

### `burn(liquidity, to)`

1. Revert with `ZeroAmount` if `liquidity == 0` and with `InsufficientLiquidity` if the
   caller holds fewer shares.
2. Run `_mintFee`.
3. `amount0 = liquidity * reserve0 / totalSupply`, `amount1 = liquidity * reserve1 / totalSupply`
   using the total supply after step 2.
4. Burn the caller's shares, reduce the reserves, transfer both amounts to `to`, update
   `kLast`, emit `Burn`.

### `swap(tokenIn, amountIn, minAmountOut, to)`

- `InvalidToken` unless `tokenIn` is `token0` or `token1`; `ZeroAmount` if `amountIn == 0`.
- `amountOut = amountIn * 997 * reserveOut / (reserveIn * 1000 + amountIn * 997)`.
- Revert with `InsufficientOutput` if `amountOut == 0` or `amountOut < minAmountOut`.
- Pull `amountIn`, send `amountOut` to `to`, update reserves, emit `Swap`.

## What the Tests Check

- Exact LP share, payout and swap amounts.
- Exact protocol shares minted on both the `mint` and the `burn` path, and that the caller's
  result is computed against the diluted supply.
- No shares when the switch is off, when `k` did not grow, or for growth that happened
  before the switch was turned on; `kLast` resets when the switch is turned off.
- The fee recipient can redeem its shares; reserves always equal the token balances.
- Access control and revert conditions.

# Isolated Lending Market with Bad-Debt Socialisation

## Problem Statement

Implement `IsolatedMarket` in `src/IsolatedMarket.sol`: a lending market with exactly one
loan asset and one collateral asset. Suppliers deposit the loan asset and earn interest.
Borrowers post collateral and borrow the loan asset. Unhealthy positions are liquidated at a
bonus. When a liquidation consumes all of a borrower's collateral and debt remains, that
debt is *bad debt*: it is written off immediately and every supplier bears the loss in
proportion to their shares.

Both tokens have 18 decimals. `price` is the value of one whole collateral token in loan
asset, scaled by `1e18`, and is set by the owner (the deployer).

## Accounting Model

The market keeps two independent share systems:

| Pair | Meaning |
| --- | --- |
| `totalSupplyAssets`, `totalSupplyShares` | everything owed to suppliers (cash plus outstanding loans) |
| `totalBorrowAssets`, `totalBorrowShares` | everything owed by borrowers |

Conversions use one virtual share and one virtual asset so they never divide by zero:

```
toShares(assets) = assets * (totalShares + 1) / (totalAssets + 1)
toAssets(shares) = shares * (totalAssets + 1) / (totalShares + 1)
```

Rounding always favours the market:

| Operation | Conversion | Rounding |
| --- | --- | --- |
| `supply` | assets to supply shares | down |
| `withdraw` | supply shares to assets | down |
| `borrow` | assets to borrow shares | up |
| `repay`, `debtOf`, bad-debt valuation | borrow shares to assets | up |
| `liquidate` | repaid assets to borrow shares | down |

Available liquidity is `totalSupplyAssets - totalBorrowAssets`.

## Required Interface

```solidity
error NotOwner();
error InvalidParameter();
error ZeroAmount();
error InsufficientShares();
error InsufficientCollateral();
error InsufficientLiquidity();
error PositionUnhealthy();
error PositionHealthy();
error RepayExceedsDebt();
error TransferFailed();

constructor(address asset_, address collateral_, uint256 lltv_, uint256 ratePerSecond_, uint256 liquidationBonus_);

function setPrice(uint256 newPrice) external;                 // owner only
function accrue() external;
function supply(uint256 assets) external returns (uint256 shares);
function withdraw(uint256 shares) external returns (uint256 assets);
function depositCollateral(uint256 amount) external;
function withdrawCollateral(uint256 amount) external;
function borrow(uint256 assets) external returns (uint256 shares);
function repay(address borrower, uint256 shares) external returns (uint256 assets);
function liquidate(address borrower, uint256 seizeCollateral) external returns (uint256 repaidAssets);
function debtOf(address user) external view returns (uint256);
function isHealthy(address user) external view returns (bool);
```

The public state variables in the starter (`owner`, `asset`, `collateral`, `lltv`,
`ratePerSecond`, `liquidationBonus`, `price`, `lastAccrual`, the four totals,
`supplyShares`, `borrowShares`, `collateralOf`) are part of the interface.

## Rules

1. **Constructor.** Reverts with `InvalidParameter` unless `0 < lltv_ < 1e18` and
   `liquidationBonus_ >= 1e18`. Sets `owner = msg.sender` and `lastAccrual = block.timestamp`.
2. **Interest.** `accrue()` adds
   `totalBorrowAssets * ratePerSecond * elapsed / 1e18` (rounded down) to both
   `totalBorrowAssets` and `totalSupplyAssets` and sets `lastAccrual`. Every function below
   except `depositCollateral` and the views accrues first.
3. **Health.** A position with no borrow shares is healthy. Otherwise it is healthy when
   `debtOf(user) <= ((collateralOf[user] * price / 1e18) * lltv / 1e18)`, both divisions
   rounding down. `debtOf` and `isHealthy` use the totals as last accrued.
4. **`supply` / `withdraw`.** Zero input, or a supply that would mint zero shares, reverts
   with `ZeroAmount`. Withdrawing more shares than owned reverts with `InsufficientShares`;
   withdrawing more assets than the available liquidity reverts with `InsufficientLiquidity`.
5. **Collateral.** `withdrawCollateral` reverts with `InsufficientCollateral` when the amount
   exceeds the balance and with `PositionUnhealthy` when the position would be unhealthy
   afterwards.
6. **`borrow`.** Reverts with `InsufficientLiquidity` when `assets` exceeds the available
   liquidity and with `PositionUnhealthy` when the position is unhealthy after the borrow.
7. **`repay(borrower, shares)`.** Anyone may repay for anyone. More shares than the borrower
   owes reverts with `RepayExceedsDebt`. The payer is charged the asset value rounded up;
   `totalBorrowAssets` is reduced by that amount, floored at zero.
8. **`liquidate(borrower, seizeCollateral)`.**
   - Reverts with `ZeroAmount` for zero, `PositionHealthy` if the position is healthy, and
     `InsufficientCollateral` if `seizeCollateral` exceeds the borrower's collateral.
   - `repaidAssets = ceil(ceil(seizeCollateral * price / 1e18) * 1e18 / liquidationBonus)`.
   - `repaidShares = toShares(repaidAssets)` rounded down. If that exceeds the borrower's
     borrow shares, revert with `RepayExceedsDebt`.
   - Reduce the borrower's shares and `totalBorrowShares` by `repaidShares`, and
     `totalBorrowAssets` by `repaidAssets` (floored at zero). Move `seizeCollateral` to the
     liquidator and pull `repaidAssets` from the liquidator.
   - **Bad debt.** If the borrower now has zero collateral and non-zero borrow shares, value
     those shares in assets (rounded up, capped at `totalBorrowAssets`), subtract that amount
     from both `totalBorrowAssets` and `totalSupplyAssets`, remove the shares from
     `totalBorrowShares` and set the borrower's shares to zero. No write-off happens while
     any collateral remains.
9. Token transfers that return `false` revert with `TransferFailed`.

## What the Tests Check

- Exact share and asset amounts for supply, withdraw, borrow and repay, including rounding.
- Interest accrual reaching suppliers and being included before liquidation.
- Liquidation pricing with the bonus, and every revert path listed above.
- Bad debt reducing `totalSupplyAssets` at once, split pro rata between suppliers, and not
  charged to a supplier who joins after the loss.
- The market's token balance always covers `totalSupplyAssets - totalBorrowAssets`.

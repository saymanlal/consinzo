# CDP Stablecoin Engine with a Stability Fee Accumulator

## Problem Statement

Implement `CdpEngine` in `src/CdpEngine.sol`. Users lock one ERC-20 collateral token in a
vault and mint a stablecoin against it. Debt grows with a stability fee that is tracked by a
global rate accumulator. Vaults that fall below the liquidation ratio can be liquidated, and
debt that cannot be recovered is recorded as bad debt and healed from accrued fees.

The engine is also the ledger of the stablecoin (`balanceOf`, `totalSupply`, `transfer`).
State variables, errors, events and the constructor are provided in the starter.

## Units

- `WAD = 1e18`, `RAY = 1e27`.
- `price`: stablecoin (WAD) per one whole collateral token (1e18 units).
- `liquidationRatio`, `liquidationPenalty`: WAD (for example `1.5e18`, `1.1e18`).
- `rate`: RAY accumulator, starts at `RAY`. `ratePerSecond`: RAY.
- A vault stores `collateral` and `normalizedDebt`. Its debt is `normalizedDebt * rate / RAY`.

## Functions and Rules

### Rate

- `currentRate()` = `rate + rate * ratePerSecond * (block.timestamp - lastDrip) / RAY`, rounded down.
  The fee is linear between two drips and compounds from one drip to the next.
- `drip()`: if time has passed, set `rate = currentRate()`, set `lastDrip`, and mint the fee
  `totalNormalizedDebt * (newRate - oldRate) / RAY` (rounded down) to `address(this)`. Emit
  `Dripped(newRate, fee)`. Always returns the stored `rate`. `mint`, `repay`, `liquidate`
  and `setRatePerSecond` drip first.
- `surplus()` is the engine's own stablecoin balance.

### Views

- `debtOf(user)` = `ceil(normalizedDebt * currentRate() / RAY)`.
- `totalDebt()` = `ceil(totalNormalizedDebt * currentRate() / RAY)`.
- `isSafe(user)` is `collateral * price >= debtOf(user) * liquidationRatio`.

### Vault owner

- `deposit(amount)`: pulls collateral with `transferFrom`. `ZeroAmount` on zero.
- `withdraw(amount)`: `ZeroAmount`, `InsufficientCollateral` if above the vault's collateral,
  `UnsafeVault` if the vault is not safe afterwards.
- `mint(amount)`: `ZeroAmount` on zero. Adds `ceil(amount * RAY / rate)` normalized debt. Reverts with
  `UnsafeVault` if the vault is not safe afterwards and with `DebtCeilingExceeded` if
  `totalDebt() > debtCeiling`. Credits `amount` stablecoin to the caller.
- `repay(amount) returns (paid)`: `ZeroAmount` on zero. If `amount >= debt` the payment is
  capped at the debt and all normalized debt is cleared; otherwise
  `floor(amount * RAY / rate)` normalized debt is removed. `paid` is burned from the caller
  (`InsufficientBalance` if the caller does not hold it).

### Liquidation

`liquidate(user, repayAmount) returns (repaid, seized)`:

1. `ZeroAmount` on zero, then drip, then `VaultIsSafe` if the vault is safe.
2. `repaid = min(repayAmount, debt)` and `seized = repaid * liquidationPenalty / price` (rounded down).
3. If `seized` exceeds the vault's collateral: `seized = collateral` and
   `repaid = ceil(collateral * price / liquidationPenalty)`.
4. Normalized debt falls by the whole amount when `repaid == debt`, otherwise by
   `floor(repaid * RAY / rate)`. `repaid` is burned from the liquidator.
5. If the vault has no collateral left but still has debt, that debt
   (`ceil(normalizedDebt * rate / RAY)`) is added to `badDebt` and the vault's normalized
   debt is removed from the vault and from `totalNormalizedDebt`.
6. The seized collateral is sent to the liquidator and `Liquidated` is emitted.

### Surplus and bad debt

- `heal() returns (healed)`: callable by anyone. Burns `min(surplus, badDebt)` from the
  engine's balance and reduces `badDebt` by the same amount.
- `withdrawSurplus(to, amount)`: owner only (`NotOwner`), reverts with `BadDebtOutstanding`
  while `badDebt > 0`, and with `InsufficientBalance` if the surplus is too small.

### Admin and token

- `setPrice(newPrice)` and `setRatePerSecond(newRate)` are owner only. The second one drips
  before changing the rate.
- `transfer(to, amount)` moves stablecoin; `InsufficientBalance` if the caller is short.

## What the Tests Check

Exact balances, normalized debt and rounding for mint, repay and liquidation at several
rates; compounding across drips; the debt ceiling including accrued fees; bad-debt write-off
and healing; access control and all revert conditions listed above.

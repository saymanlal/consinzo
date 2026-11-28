# Strategy Vault with Harvests, Fee Shares and Loss Handling

## Problem Statement

Implement `StrategyVault` in `src/StrategyVault.sol`. Depositors receive shares of a pool of
one ERC-20 asset. The owner moves part of the pool into an external strategy. The vault does
not look at balances to price its shares: it keeps two numbers, `idleAssets` and
`strategyDebt`, and only a `harvest()` updates the debt to what the strategy reports.

Interfaces, errors, events, constants and state variables are provided in the starter. The
vault keeps its own share ledger (`balanceOf`, `totalSupply`); share transfers are not part
of this exercise.

## Accounting

- `totalAssets() = idleAssets + strategyDebt`. Tokens sent directly to the vault and gains
  or losses inside the strategy do not change it until they are reported.
- `convertToShares(assets) = assets * totalSupply / totalAssets()` and
  `convertToAssets(shares) = shares * totalAssets() / totalSupply`, both rounded down, and
  both 1:1 while `totalSupply == 0`.

## Functions

### deposit(assets, receiver) returns (shares)

`ZeroAmount` on zero. `shares = convertToShares(assets)`; `ZeroShares` if that is zero.
Mints to `receiver`, increases `idleAssets`, pulls the assets from the caller.

### withdraw(shares, receiver, maxLossBps) returns (assets)

1. `ZeroAmount` on zero, `InsufficientShares` if the caller holds fewer shares.
2. `value = convertToAssets(shares)`; burn the shares.
3. If `value > idleAssets`, call `strategy.withdraw(value - idleAssets)`. Use the increase of
   the vault's token balance as the amount received, not the return value. Reduce
   `strategyDebt` by the amount **requested** and add the amount received to `idleAssets`.
4. If less was received than requested, the shortfall is this withdrawal's `loss`. Revert
   with `LossTooHigh` if `loss * 10_000 > value * maxLossBps`; otherwise the payout is
   `value - loss`.
5. Reduce `idleAssets` by the payout and transfer it to `receiver`.

The remaining shareholders' price per share must not change because of another user's
shortfall.

### invest(amount) / divest(amount)

Owner only (`NotOwner`).

- `invest`: `InsufficientIdle` if `amount > idleAssets`; moves tokens to the strategy and
  moves `amount` from `idleAssets` to `strategyDebt`.
- `divest` returns the amount received: `InsufficientDebt` if `amount > strategyDebt`; pulls
  from the strategy (measured by balance), `strategyDebt -= amount`,
  `idleAssets += received`, and any shortfall is added to `unrecoveredLoss`.

### harvest() returns (profit, loss, feeShares)

Owner only. Let `reported = strategy.totalAssets()`. Set `strategyDebt = reported`.

- `reported > debt`: `profit = reported - debt`. First
  `recovered = min(profit, unrecoveredLoss)` reduces `unrecoveredLoss`. The fee in assets is
  `(profit - recovered) * performanceFeeBps / 10_000`. If the fee and the share supply are
  both non-zero, mint `feeShares = fee * totalSupply / (totalAssets() - fee)` (rounded down,
  with `totalAssets()` already including the profit) to `feeRecipient`.
- `reported < debt`: `loss = debt - reported` is added to `unrecoveredLoss`.
- Emit `Harvest(profit, loss, feeShares)`.

### Constructor

Reverts with `FeeTooHigh` if `performanceFeeBps > 5_000`.

## What the Tests Check

Share and asset amounts to the wei for deposits, fee-share minting and redemption; the
high-water mark across several harvests; donations to the vault and to the strategy;
withdrawals with a strategy that loses part of what it returns, including one that lies
about the amount; loss tolerance; access control and all revert conditions.

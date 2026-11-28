# Epoch Options Vault with Queued Deposits and Rolls

## Problem Statement

Implement `EpochVault` in `src/EpochVault.sol`, the accounting core of a covered-call style
vault. The vault works in epochs (one option cycle each). During an epoch the locked assets
are at risk: the vault earns a premium and may owe a payout to the option buyer. The owner
acts as keeper and option counterparty and ends each epoch with `roll(premium, payout)`.

- A deposit made during epoch `N` waits in a queue. It becomes shares at the roll of epoch
  `N` and takes part from epoch `N + 1`. It gets none of epoch `N`'s result.
- A withdrawal requested during epoch `N` stays at risk until epoch `N` is rolled and is then
  paid at that roll's price.

State variables, structs, errors and events are provided in the starter.

## Accounting Buckets

`lockedAssets + totalPending + withdrawalReserve` must always equal the vault's token balance.

## Roll

`roll(premium, payout)` is owner only (`NotOwner`). Let `supply = totalShares` and
`E = epoch` at the time of the call.

1. Price per share (`WAD = 1e18`):
   - `supply == 0`: `premium` and `payout` must both be zero (`NothingAtRisk`), the price is
     `WAD` and `endAssets = lockedAssets`.
   - otherwise: revert with `PayoutTooLarge` if `payout >= lockedAssets + premium`;
     `endAssets = lockedAssets + premium - payout`; `price = endAssets * WAD / supply`
     (rounded down); a price of zero also reverts with `PayoutTooLarge`.
2. `pricePerShare[E] = price`.
3. Queued withdrawals: `withdrawn = queuedShares * price / WAD` (rounded down) moves from the
   locked bucket to `withdrawalReserve`, and the queued shares are burned.
4. Pending deposits: `minted = totalPending * WAD / price` (rounded down) shares are created
   and the pending assets become locked.
5. Result: `totalShares = supply - queuedShares + minted`,
   `lockedAssets = endAssets - withdrawn + totalPending`, `queuedShares = 0`,
   `totalPending = 0`, emit `Rolled(E, price, minted, withdrawn)`, `epoch = E + 1`.
6. Pull `premium` from the owner with `transferFrom` and send `payout` to the owner.

## User Functions

- `deposit(amount)`: `ZeroAmount` on zero. If the caller has a pending deposit from an
  earlier epoch it is redeemed first. The amount is added to the caller's pending deposit for
  the current epoch.
- `cancelDeposit(amount)`: `ZeroAmount` on zero. Only assets deposited in the current epoch
  can be returned; otherwise `InsufficientPending`.
- `redeem()`: converts the caller's pending deposit from an earlier epoch into
  `amount * WAD / pricePerShare[depositEpoch]` shares (rounded down). No-op if there is none.
- `shareBalanceOf(user)`: `shares[user]` plus the shares of an unredeemed pending deposit
  whose epoch has rolled.
- `requestWithdraw(shareAmount)`: `ZeroAmount` on zero; redeems first; reverts with
  `WithdrawalNotClaimed` if the caller has a request from an earlier epoch that was not
  completed; `InsufficientShares` if the caller has fewer redeemed shares. Requests in the
  same epoch accumulate.
- `completeWithdraw() returns (assets)`: `NoWithdrawal` if there is no request,
  `WithdrawalNotReady` if its epoch has not rolled. Pays
  `shares * pricePerShare[requestEpoch] / WAD` (rounded down) from the withdrawal reserve.

## What the Tests Check

Exact share and asset amounts across several epochs with premiums and payouts, that queued
deposits do not share the running epoch's result while queued withdrawals do, rounding in
favour of the vault, the reserve being isolated from later losses, empty-vault rolls, every
revert condition, and the bucket identity after each step.

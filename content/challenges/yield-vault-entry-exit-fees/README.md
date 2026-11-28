# Yield Vault Shares with Deposit and Withdrawal Fees

## Problem Statement

Implement `FeeVault` in `src/FeeVault.sol`. Depositors receive shares of a pool of one ERC-20
asset. Yield is added to the pool through `addYield`, which raises the value of every share.
The vault charges a fee on the way in and on the way out; both fees are paid immediately to a
fixed fee recipient. Shares are internal balances (not transferable in this exercise).

## Interface

```solidity
constructor(address asset_, uint256 depositFeeBps_, uint256 withdrawFeeBps_, address feeRecipient_)

function convertToShares(uint256 assets) public view returns (uint256)
function convertToAssets(uint256 shares) public view returns (uint256)
function previewDeposit(uint256 assets) public view returns (uint256 shares, uint256 fee)
function previewRedeem(uint256 shares) public view returns (uint256 assetsOut, uint256 fee)

function deposit(uint256 assets) external returns (uint256 shares)
function redeem(uint256 shares) external returns (uint256 assetsOut)
function addYield(uint256 amount) external
```

Public state declared in the starter: `asset`, `depositFeeBps`, `withdrawFeeBps`,
`feeRecipient`, `totalAssets`, `totalSupply`, `balanceOf(address)`, and the constant
`MAX_FEE_BPS = 1000`.

## Rules

1. The constructor reverts with `FeeTooHigh()` if either fee exceeds `MAX_FEE_BPS` and with
   `ZeroAddress()` if `feeRecipient_` is `address(0)`.
2. `totalAssets` is a stored number. It changes only in `deposit`, `redeem` and `addYield`.
   Tokens transferred to the vault by other means are ignored.
3. Conversions round down:
   - `convertToShares(a) = a` if `totalSupply == 0`, else `a * totalSupply / totalAssets`;
   - `convertToAssets(s) = s` if `totalSupply == 0`, else `s * totalAssets / totalSupply`.
4. `previewDeposit(assets)`: `fee = assets * depositFeeBps / 10_000`,
   `shares = convertToShares(assets - fee)`.
5. `previewRedeem(shares)`: `gross = convertToAssets(shares)`,
   `fee = gross * withdrawFeeBps / 10_000`, `assetsOut = gross - fee`.
6. `deposit(assets)`:
   - `ZeroAmount()` if `assets == 0`; `ZeroShares()` if the computed shares are `0`;
   - pulls `assets` from the caller, forwards the fee to `feeRecipient`;
   - increases `totalAssets` by `assets - fee`, mints the shares;
   - emits `Deposited(user, assets, shares, fee)`.
7. `redeem(shares)`:
   - `ZeroAmount()` if `shares == 0`; `InsufficientShares()` if the caller has fewer;
   - burns the shares, decreases `totalAssets` by the gross amount;
   - sends the fee to `feeRecipient` and `assetsOut` to the caller;
   - emits `Redeemed(user, shares, assetsOut, fee)`.
8. `addYield(amount)`: `ZeroAmount()` for zero; `NoShareholders()` if `totalSupply == 0`;
   pulls `amount` from the caller and adds it to `totalAssets`; emits `YieldAdded(from, amount)`.
9. A zero fee must not trigger a token transfer to the recipient.
10. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Share and fee amounts for deposits and redemptions before and after yield.
- That fees reach the recipient and never dilute or inflate `totalAssets`.
- Rounding, `ZeroShares` protection, ignored direct transfers and constructor validation.
- Solvency: the vault always holds at least `totalAssets`, and the last holder can leave.

# Collateralised Lending at a Fixed Price and LTV

## Problem Statement

Implement `CollateralLender` in `src/CollateralLender.sol`. Users lock a collateral token and
borrow a debt token against it. The price of the collateral is fixed at construction and there
is no interest: the task is to get the position accounting and the solvency checks exactly
right. The debt tokens that can be lent are whatever the contract holds.

## Interface

```solidity
constructor(address collateralToken_, address debtToken_, uint256 price_, uint256 ltvBps_)

function collateralValue(uint256 collateralAmount) public view returns (uint256)
function borrowLimit(uint256 collateralAmount) public view returns (uint256)
function maxBorrow(address user) public view returns (uint256)
function availableToBorrow(address user) external view returns (uint256)

function depositCollateral(uint256 amount) external
function borrow(uint256 amount) external
function repay(uint256 amount) external returns (uint256 paid)
function withdrawCollateral(uint256 amount) external
```

Public state declared in the starter: `collateralToken`, `debtToken`, `price`, `ltvBps`,
`collateralOf(address)`, `debtOf(address)`, `totalCollateral`, `totalDebt`.

## Rules

1. `price` is the value of `1e18` base units of collateral, in base units of the debt token:
   `collateralValue(c) = c * price / 1e18` (rounded down).
2. `borrowLimit(c) = collateralValue(c) * ltvBps / 10_000` (rounded down).
   `maxBorrow(user) = borrowLimit(collateralOf[user])`.
3. `availableToBorrow(user)` is `maxBorrow(user) - debtOf[user]`, or `0` if the debt is not
   below the limit.
4. `depositCollateral(amount)`: `ZeroAmount()` for zero; pulls collateral; emits
   `CollateralDeposited(user, amount)`.
5. `borrow(amount)`, checks in this order:
   - `ZeroAmount()` for zero;
   - `ExceedsBorrowLimit()` if `debtOf[user] + amount > maxBorrow(user)`;
   - `InsufficientLiquidity()` if the contract holds fewer than `amount` debt tokens.
   Then it records the debt, sends the tokens and emits `Borrowed(user, amount)`.
6. `repay(amount)`: `ZeroAmount()` for zero; `NoDebt()` if the caller owes nothing. It pulls
   `min(amount, debtOf[caller])` debt tokens, reduces the debt by that amount, returns it and
   emits `Repaid(user, paid)`.
7. `withdrawCollateral(amount)`, checks in this order:
   - `ZeroAmount()` for zero;
   - `InsufficientCollateral()` if `amount > collateralOf[caller]`;
   - `ExceedsBorrowLimit()` if the caller's debt would exceed
     `borrowLimit(collateralOf[caller] - amount)`.
   Then it returns the collateral and emits `CollateralWithdrawn(user, amount)`.
8. A position at exactly its limit is valid. `totalCollateral` and `totalDebt` equal the sums
   over all users at all times.
9. Token transfers that return `false` revert with `TransferFailed()`.

## What the tests check

- Limits and values for round and awkward amounts, including dust positions.
- Exact boundaries for borrowing and for withdrawing collateral with outstanding debt.
- Capped repayment, isolation between borrowers and pool liquidity limits.
- The documented order of the revert conditions.

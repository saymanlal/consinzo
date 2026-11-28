# Defend a Lending Market Against the Empty-Market Donation Attack

`TwinMarket` is a small money market with two assets, market `0` and market `1`. Suppliers
`mint` shares of a market. Shares are collateral: an account may borrow from either market
while `debtValue <= collateralValue`, where collateral is counted at 75% and both assets are
valued 1:1. Borrowing adds a 1% fee to the debt, which is how suppliers earn and why a
market's exchange rate rises above `1e18`.

Liquidations are out of scope for this mission.

## The exploit

Market 0 has just been listed and is empty. Market 1 holds supplier funds.

1. The attacker mints `1e18` shares of market 0 and redeems all but 2 wei of them.
2. The attacker transfers 1000 tokens directly to the contract. `exchangeRate(0)` is computed
   from `balanceOf(this)`, so 2 wei of shares are now "worth" 1000 tokens.
3. With 750 tokens of borrowing power the attacker borrows 370 tokens from market 1.
4. The attacker calls `redeemUnderlying(0, 1000e18)`. The shares to burn are
   `1000e18 * 2 / (1000e18 + 2)`, which rounds down to 1. The health check runs before the
   tokens leave, so the remaining share still looks like 500 tokens of collateral.

The attacker has the donation back, keeps the 370 borrowed tokens, and leaves a debt backed
by one wei.

## Your task

Patch `src/TwinMarket.sol`. Keep the interface unchanged.

```solidity
constructor(address token0, address token1);
function mint(uint256 id, uint256 amount) external returns (uint256 sharesMinted);
function redeem(uint256 id, uint256 shareAmount) external returns (uint256 amountOut);
function redeemUnderlying(uint256 id, uint256 amount) external returns (uint256 sharesBurned);
function borrow(uint256 id, uint256 amount) external;
function repay(uint256 id, uint256 amount) external returns (uint256 repaid);
function cash(uint256 id) external view returns (uint256);
function totalAssets(uint256 id) external view returns (uint256);   // cash + totalBorrows
function exchangeRate(uint256 id) external view returns (uint256);  // 1e18 when no shares exist
function collateralValue(address account) external view returns (uint256);
function debtValue(address account) external view returns (uint256);
```

### Required properties

1. **Internal cash accounting.** `cash(id)` is the amount that entered through `mint` and
   `repay` minus the amount that left through `redeem`, `redeemUnderlying` and `borrow`.
   Tokens sent straight to the contract must not change `cash`, `totalAssets` or
   `exchangeRate`.
2. **Rounding in favour of the pool.** `redeemUnderlying` burns
   `ceil(amount * totalShares / totalAssets)` shares. `mint` and `redeem` keep rounding down.
3. **Health is checked on the final state.** `redeem`, `redeemUnderlying` and `borrow` revert
   with `Undercollateralized()` if the account is unhealthy once all balances of the call are
   updated.

Other rules (already implemented, keep them): `InvalidMarket()` for ids other than 0 and 1,
`ZeroAmount()` for zero inputs, `ZeroShares()` when a mint would create no shares,
`InsufficientShares()`, `InsufficientCash()`, and `repay` caps the amount at the caller's debt.

## What the tests check

- The four-step exploit fails: the donation does not move the exchange rate and the borrow
  reverts with `Undercollateralized()`.
- `redeemUnderlying` never burns fewer shares than the amount is worth, including for 1 wei.
- Supplying, borrowing, repaying with the fee, and redeeming work with exact amounts.

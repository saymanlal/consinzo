# Linear Bonding Curve with an Exact Reserve Invariant

## Problem Statement

Implement `BondingCurve` in `src/BondingCurve.sol`. The contract is its own market maker: it
mints its token to buyers for ETH and burns it from sellers for ETH. The spot price rises
linearly with the supply:

```
price(S) = basePrice + slope * S / 1e18        (wei per whole token, S in base units)
```

The ETH that must be held to back a supply `S` is the area under that line:

```
reserveFor(S) = basePrice * S / 1e18  +  slope * S * S / (2 * 1e36)
```

Each of the two terms is computed with one integer division, rounded down.

## Interface

```solidity
constructor(uint256 basePrice_, uint256 slope_)

function currentPrice() external view returns (uint256)
function reserveFor(uint256 supply) public view returns (uint256)
function buyCost(uint256 amount) public view returns (uint256)
function sellRefund(uint256 amount) public view returns (uint256)

function buy(uint256 amount) external payable returns (uint256 cost)
function sell(uint256 amount, uint256 minRefund) external returns (uint256 refund)
```

Public state declared in the starter: `basePrice`, `slope`, `totalSupply`, `reserve`,
`balanceOf(address)`. The token is not transferable in this exercise.

## Rules

1. `buyCost(a) = reserveFor(totalSupply + a) - reserveFor(totalSupply)`.
2. `sellRefund(a) = reserveFor(totalSupply) - reserveFor(totalSupply - a)`; it reverts if
   `a > totalSupply`.
3. `buy(amount)`:
   - reverts with `ZeroAmount()` if `amount == 0`;
   - reverts with `InsufficientPayment()` if `msg.value < buyCost(amount)`;
   - mints `amount` to the caller, adds the cost to `reserve`;
   - returns `msg.value - cost` to the caller (`TransferFailed()` if that send fails);
   - emits `Bought(buyer, amount, cost)` and returns the cost.
4. `sell(amount, minRefund)`:
   - reverts with `ZeroAmount()` if `amount == 0`;
   - reverts with `InsufficientBalance()` if `amount > balanceOf[caller]`;
   - reverts with `SlippageExceeded()` if `sellRefund(amount) < minRefund`;
   - burns `amount`, subtracts the refund from `reserve`, sends the refund
     (`TransferFailed()` on failure);
   - emits `Sold(seller, amount, refund)` and returns the refund.
5. **Reserve invariant:** after every successful call,
   `reserve == reserveFor(totalSupply)` and the contract holds at least `reserve` wei.
6. `currentPrice()` returns `basePrice + slope * totalSupply / 1e18`.

## What the tests check

- Costs and refunds for known curve parameters.
- Path independence: buying in several pieces costs exactly the same as buying at once, and a
  full round trip returns exactly what was paid.
- The reserve invariant after interleaved trades by several users, including dust amounts.
- Refund of excess ETH, slippage protection and the revert paths.

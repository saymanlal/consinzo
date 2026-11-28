# Dutch-Auction Collateral Liquidator

## Problem Statement

Implement `CollateralAuctionHouse` in `src/CollateralAuctionHouse.sol`. The owner (think of a
lending engine) hands over seized collateral together with the debt that must be recovered.
The house sells the collateral for a quote token at a price that falls linearly from a start
price to a floor. Anyone can buy part or all of the lot at the current price. The house
never raises more quote than the debt: once the debt is covered the auction ends and the
unsold collateral is returned to the liquidated user. If the whole lot is sold and debt is
still outstanding, the remainder is recorded as bad debt.

There is one collateral token and one quote token, both with 18 decimals. Prices are quote
per one whole collateral token, scaled by `1e18` (`WAD`).

## Required Interface

```solidity
error NotOwner();
error InvalidConfig();
error ZeroAmount();
error AuctionNotActive();
error PriceTooHigh();

event AuctionStarted(uint256 indexed id, address indexed user, uint256 lot, uint256 debt, uint256 startPrice);
event Take(uint256 indexed id, address indexed taker, uint256 collateralOut, uint256 quoteIn, uint256 price);
event AuctionClosed(uint256 indexed id, uint256 collateralRefund, uint256 badDebt);

constructor(address collateral_, address quote_, uint256 duration_, uint256 floorBps_);

function owner() external view returns (address);
function collateral() external view returns (address);
function quote() external view returns (address);
function duration() external view returns (uint256);
function floorBps() external view returns (uint256);
function auctionCount() external view returns (uint256);
function pendingProceeds() external view returns (uint256);
function totalBadDebt() external view returns (uint256);
function auctions(uint256 id) external view returns (
    address user, uint256 lot, uint256 debt, uint256 startPrice, uint256 startTime, bool active
);

function start(address user, uint256 lot, uint256 debt, uint256 startPrice) external returns (uint256 id);
function priceOf(uint256 id) external view returns (uint256);
function take(uint256 id, uint256 maxCollateral, uint256 maxPrice, address recipient)
    external returns (uint256 collateralOut, uint256 quoteIn);
function withdrawProceeds(address to) external returns (uint256 amount);
```

## Rules

1. **Constructor.** `owner = msg.sender`. Reverts with `InvalidConfig` if `duration_ == 0` or
   `floorBps_ > 10000`.
2. **`start`** (owner only, `NotOwner`). Reverts with `ZeroAmount` if `lot`, `debt` or
   `startPrice` is zero. Pulls `lot` collateral from the caller with `transferFrom`, stores
   the auction with `startTime = block.timestamp` and `active = true`, and returns the id.
   Ids are sequential starting at `0`; `auctionCount` is the number of auctions started.
3. **`priceOf`** reverts with `AuctionNotActive` for an auction that is not active (never
   started or closed). With `floor = startPrice * floorBps / 10000` and
   `elapsed = block.timestamp - startTime`:
   - `elapsed >= duration`: the price is `floor` and stays there;
   - otherwise `startPrice - (startPrice - floor) * elapsed / duration`.
4. **`take`**
   1. `AuctionNotActive` if the auction is not active; `ZeroAmount` if `maxCollateral == 0`.
   2. `price = priceOf(id)`; revert with `PriceTooHigh` if `price > maxPrice`.
   3. `slice = min(maxCollateral, lot)` and `owe = ceil(slice * price / 1e18)`.
   4. If `owe > debt`: `owe = debt` and `slice = owe * 1e18 / price` (rounded down). The
      slice may be zero in this branch; the take still goes through.
   5. `lot -= slice`, `debt -= owe`, `pendingProceeds += owe`. Pull `owe` quote from the caller
      and send `slice` collateral to `recipient`. Emit `Take`.
   6. If `debt == 0`: the auction closes, the remaining `lot` is transferred to `user`, the
      stored `lot` becomes `0`, and `AuctionClosed(id, refund, 0)` is emitted.
      Otherwise, if `lot == 0`: the auction closes, `totalBadDebt += debt` (the stored `debt`
      keeps the shortfall), and `AuctionClosed(id, 0, debt)` is emitted.
   7. Returns `(slice, owe)`.
5. **`withdrawProceeds`** (owner only). Transfers the whole `pendingProceeds` to `to`, resets
   it to zero and returns the amount.

## Rounding Summary

| Quantity | Direction | Reason |
| --- | --- | --- |
| price decay | decay rounds down, so the price rounds up | never undersell |
| `owe` | up | taker pays for every fraction of collateral |
| `slice` when capped by debt | down | taker never receives more than was paid for |

## What the Tests Check

- The price curve at the start, in the middle, at the end and long after the end.
- Partial takes, debt-capped takes with a refund to the liquidated user, and a full sale
  below the debt that records bad debt.
- Exact rounding of `owe`, `slice` and the price.
- Independent accounting of concurrent auctions; the collateral held always equals the sum
  of active lots and the quote held equals `pendingProceeds`.
- Access control and all revert conditions.

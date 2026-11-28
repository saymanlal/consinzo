# English Auction with Pull Refunds and Anti-Sniping Extension

## Problem Statement

Implement `EnglishAuction` in `src/EnglishAuction.sol`: an open ascending auction paid in ETH.

The deployer is the `seller`. Bidders call `bid()` with ETH. Each new highest bid replaces the
previous one; the outbid bidder's ETH is not sent back automatically but becomes withdrawable.
A bid that arrives when less than `extensionWindow` seconds remain moves `endTime` so that exactly
`extensionWindow` seconds remain. When the auction is over anyone can call `settle()` to pay the
seller.

## Required Interface

```solidity
constructor(uint256 _reservePrice, uint256 _minIncrement, uint256 _duration, uint256 _extensionWindow)

function bid() external payable
function withdraw() external
function settle() external

// public state (already declared in the starter)
address public immutable seller;
uint256 public immutable reservePrice;
uint256 public immutable minIncrement;
uint256 public immutable extensionWindow;
uint256 public endTime;            // starts at block.timestamp + _duration
address public highestBidder;
uint256 public highestBid;
bool public settled;
mapping(address => uint256) public pendingReturns;
```

## Rules

1. `bid()`
   - reverts with `AuctionEnded()` when `block.timestamp >= endTime`;
   - the first bid must be at least `reservePrice`; every later bid must be at least
     `highestBid + minIncrement`; otherwise revert with `BidTooLow()`;
   - the previous highest bid (if any) is added to `pendingReturns[previousHighestBidder]`;
   - the current highest bidder may bid again; their earlier bid is credited to
     `pendingReturns` like anyone else's (bids are not cumulative);
   - if `endTime - block.timestamp < extensionWindow`, set
     `endTime = block.timestamp + extensionWindow`;
   - emits `BidPlaced(bidder, amount, endTime)` with the possibly updated end time.
2. `withdraw()` pays the caller their `pendingReturns` balance and zeroes it. It reverts with
   `NothingToWithdraw()` when the balance is zero. It works before and after the auction ends.
3. `settle()`
   - reverts with `AuctionNotEnded()` when `block.timestamp < endTime`;
   - reverts with `AlreadySettled()` on a second call;
   - can be called by anyone; sets `settled = true`, sends `highestBid` to the seller if there was
     a bid, and emits `Settled(highestBidder, highestBid)`. With no bids it only sets the flag and
     emits the event with zero values.
4. Any failed ETH transfer reverts with `TransferFailed()`.
5. `bid()` must never make an external call to a bidder.

## What the Tests Check

- Public tests: bid ordering, refunds through `withdraw`, the extension on a late bid, and
  settlement.
- Hidden tests: reserve and increment boundaries, the extension boundary second and repeated
  extensions, a bidder contract that rejects ETH being outbid, accumulated refunds, double
  settlement, settlement without bids, and exact ETH conservation.

# Reference Solution Explanation

## Structure

The contract holds three kinds of ETH and never mixes them up:

- the current highest bid, owned by the auction until settlement;
- `pendingReturns`, owned by outbid bidders;
- nothing else. After every bidder has withdrawn and `settle` has run, the balance is zero.

`bid` only moves numbers: the previous leader's bid becomes a `pendingReturns` credit and the new
bid takes its place. Because `bid` makes no external call, no bidder can make another bidder's
transaction fail.

## The soft close

```solidity
if (endTime - block.timestamp < extensionWindow) {
    endTime = block.timestamp + extensionWindow;
}
```

The subtraction cannot underflow because `bid` already required `block.timestamp < endTime`. The
new end time is measured from the bid, not from the old end time, so every late bid leaves exactly
one window for a counter-bid. With exactly `extensionWindow` seconds left there is no extension.

## Pitfalls

- **Push refunds.** Sending the outbid amount inside `bid` lets a contract with a reverting
  `receive` hold the lead forever. This is SWC-113.
- **Overwriting instead of adding.** A bidder can be outbid several times; refunds must be added to
  `pendingReturns` with `+=`.
- **Leader re-bids.** The leader's old bid must be credited back, otherwise it is lost.
- **Settlement with no bids.** `settle` must still succeed and must not send anything.
- **Order in `settle` and `withdraw`.** State is updated before the external call, so re-entering
  either function finds `settled == true` or a zero balance.

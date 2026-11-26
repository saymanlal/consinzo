# Fix King-of-Ether Push-Payment Denial of Service

`PullAuction.bid()` refunds the previous leader synchronously via `.call{value: highestBid}("")`. A malicious contract that reverts in `receive()` permanently blocks any higher bid.

## Objective
Record refunds in `pendingReturns[previousLeader]` and let users withdraw via `withdrawRefund()`.
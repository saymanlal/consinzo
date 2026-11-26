# Fix King-of-Ether Push-Payment Denial of Service

Accumulates outbid refunds in `pendingReturns` rather than pushing ETH inline inside `bid()`.

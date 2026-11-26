# Linear-Decay Dutch Auction

Implement `currentPrice()` decaying linearly from `startPrice` down to `reservePrice` over `duration`, and `buy()` accepting `msg.value >= price` and refunding overpayment.
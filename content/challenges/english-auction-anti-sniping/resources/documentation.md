# English Auctions On-Chain: Background

## Ascending auctions

In an English auction the price rises with every bid and the last bidder wins at their own bid.
The contract has to hold the leading bid in escrow so the winner cannot walk away, and has to give
every earlier bidder their money back.

## Pull payments

The straightforward way to refund the previous leader is to send their ETH back inside the next
`bid` call. That makes the success of one user's transaction depend on code controlled by another
user: a bidder that is a contract can revert on receipt, or burn all the gas, and no higher bid can
ever land. The withdrawal ("pull") pattern removes the dependency: the contract only records what
it owes, and each party collects their own balance in a separate transaction.

## Sniping and soft closes

With a hard end time, the rational strategy is to bid in the last block, leaving nobody time to
respond. On a blockchain this turns the auction into a gas-price contest for the final block and
tends to lower the seller's revenue. A soft close fixes this: any bid that arrives within a window
before the end moves the end so that a full window remains. The auction ends only when a whole
window passes with no new bid.

## Minimum increments

Without a minimum increment a bidder can outbid by 1 wei, and with a soft close they could keep
the auction open almost for free. A minimum increment makes every extension cost something.

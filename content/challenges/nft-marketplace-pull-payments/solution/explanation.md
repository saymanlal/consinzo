# Reference Solution Explanation

## Structure

A listing is a small state machine: created active by `list`, closed by exactly one of
`buy` or `cancel`. Every function that acts on a listing starts with the `active` check,
which also rejects ids that were never created because their storage is zero.

## Escrow

`list` moves the token into the marketplace. With the alternative (the seller keeps the
token and only approves the marketplace) a listing can outlive the seller's ownership or
approval, and each purchase must re-check both. Escrow also makes "list the same token
twice" impossible without extra bookkeeping: after the first listing the marketplace is
the owner, so the second call fails the `ownerOf(tokenId) == msg.sender` check.

## Pull payments

`buy` only writes credits. Three parties may be owed ETH after a trade:

- the fee recipient: `price * feeBps / 10_000`, rounded down;
- the seller: `price - fee`, computed by subtraction so that fee and proceeds always add
  up to exactly `price` regardless of rounding;
- the buyer: `msg.value - price`.

Sending any of these inside `buy` would let a contract that reverts on receipt block the
sale, and would hand control to an arbitrary address in the middle of the trade.
`totalPending` tracks the sum of credits, so the invariant
`address(this).balance == totalPending` is easy to state and test.

## Ordering

- `buy` sets `active = false` before calling `transferFrom` on the NFT contract. The NFT
  contract is chosen by the seller and may call back; if the listing were still active the
  callback could buy or cancel it a second time.
- `withdraw` zeroes the caller's credit before the ETH transfer. A recipient that
  re-enters `withdraw` finds a zero balance and gets `NothingToWithdraw()`.
- If the ETH transfer fails the whole call reverts, which restores the credit.

## Fee snapshot

The listing stores the fee rate at creation. Otherwise the owner could raise the fee to
the maximum immediately before a purchase and take more of the seller's proceeds than the
seller agreed to. The recipient address is read at purchase time; changing where the fee
goes does not affect the seller.

## Pitfalls

- Computing the seller's share with a second multiplication, which can lose or create a
  wei.
- Refunding overpayment with a direct transfer inside `buy`.
- Checking `NotSeller` before `ListingNotActive`: for an unknown id the stored seller is
  `address(0)` and the caller would get a misleading error.

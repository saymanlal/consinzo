# Fixed-Rate Token Sales

A fixed-rate sale is the simplest primary-market mechanism: the contract holds an inventory of
tokens and exchanges them for ETH at a constant price.

## Rate and units

ETH has 18 decimals. If `rate` is "token base units per 1 ETH", then a payment of `w` wei buys
`w * rate / 1e18` base units. With an 18-decimal token and `rate = 2000e18`, one ETH buys 2000
whole tokens. Integer division truncates, so dust payments can round down; always multiply
first.

## Caps

- The **hard cap** bounds the total ETH the sale may ever accept. Track it with a dedicated
  counter. The contract balance is not a substitute: it drops when the owner withdraws and it
  can be increased by forced transfers.
- The **per-buyer limit** bounds what one address may contribute in total. It needs a
  `mapping(address => uint256)` of cumulative contributions.

## Payable functions and withdrawals

`msg.value` is credited to the contract before the function body runs. To pay the proceeds out,
use `call{value: amount}("")` and check the returned flag; `transfer` and `send` forward a fixed
2300 gas and fail for many smart-contract wallets.

## Checks, effects, interactions

Do all validation first, then update storage, then call external contracts (the token, the
owner). With this order a re-entrant call observes final accounting and cannot bypass a cap.

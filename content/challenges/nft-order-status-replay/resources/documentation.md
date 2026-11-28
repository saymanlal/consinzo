# Order lifecycles in NFT marketplaces

## Orders are reusable unless you make them single-use

A listing, whether stored on-chain or signed off-chain, says "anyone may take token T from
me for price P". The marketplace can execute it because the maker granted
`setApprovalForAll` to the marketplace contract. That approval is not consumed by a sale.
If the order is not explicitly closed, it remains executable whenever its preconditions
hold again: the maker owns the token and the taker pays the price. Old orders at old prices
are the classic way collectors lose valuable tokens after buying them back.

## A minimal state machine

```
None --createOrder--> Open --fillOrder--> Filled
                        \---cancelOrder--> Cancelled
```

Rules that keep it sound:

- Every transition checks the current state.
- Terminal states have no outgoing transitions.
- The state change is written before external calls (checks, effects, interactions).

## Nonces for bulk cancellation

Cancelling orders one by one costs a transaction each. Marketplaces therefore store a
per-maker counter and stamp its value into each order. Incrementing the counter invalidates
all orders carrying the old value in one transaction. The stamp only helps if the fill path
compares it with the live counter.

## ERC-721 approvals

`setApprovalForAll(operator, true)` lets the operator move every token of the owner in that
collection until it is revoked. Marketplace code must assume this power is permanent and
gate every use of it on a live, unconsumed order.

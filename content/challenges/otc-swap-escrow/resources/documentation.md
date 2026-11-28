# OTC Escrow Swaps

## The pattern

Two parties want to swap tokens without trusting each other and without an AMM. One side (the
maker) locks its tokens in a contract together with its terms. The other side (the taker)
accepts the terms by paying; the contract performs both legs in one transaction, so either both
happen or neither does.

## Fixed price and partial fills

An offer of `S` sell tokens for `B` buy tokens fixes the price at `B / S`. A partial fill of
`t` sell tokens costs `t * B / S`. Since this is rarely an integer, the contract has to choose
who absorbs the rounding. The party that chooses the amount (the taker) could exploit rounding
in its favour by choosing convenient amounts, so the rounding goes against the taker:

```
cost = (t * B + S - 1) / S        // ceiling division
```

## Approvals

Both legs use `transferFrom`: the maker approves the escrow for the sell token before creating
the order, the taker approves it for the buy token before filling. The contract should check
the boolean returned by ERC-20 calls.

## Lifecycle

```
created (active) --fill (partial)--> active --fill (rest)--> closed
        \------------------ cancel ------------------------> closed
```

A closed order must reject every further action.

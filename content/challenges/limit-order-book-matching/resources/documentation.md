# Limit Order Book Notes

## Limit orders and the book

A limit order states a side, a quantity and the worst acceptable price. Orders that cannot
trade immediately rest in the book. The highest resting buy price is the best bid, the
lowest resting sell price is the best ask, and the difference is the spread.

## Price-time priority

When an incoming order can trade with several resting orders, the order with the best price
trades first. Among orders at the same price, the one that arrived first trades first. The
trade executes at the resting order's price: the resting order committed to that price
earlier, and the incoming order only promised to do no worse than its limit.

## Makers and takers

The resting order is the maker and the incoming order is the taker. Makers lock their funds
in the book when they are placed so a match can always be settled. Takers settle at the
moment of the match.

## Linked lists in storage

Solidity has no ordered container. A mapping from id to a struct with `prev` and `next` ids
forms a doubly linked list. Id `0` acts as the null pointer, which is why real ids start at
one. Removing a node means re-pointing its neighbours (or the head) and deleting the node.

## Exact arithmetic

Quoting prices as "quote units per base unit" makes every trade value a product of two
integers. There is no division and therefore no rounding to reason about, which makes the
escrow invariant exact.

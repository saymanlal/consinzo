# Ring Buffers: Background

## The idea

A ring buffer (circular buffer) is a fixed-size array used as if its ends were joined. A write
position advances by one on every insert and wraps to the start with the modulo operator. When the
buffer is full, each new element overwrites the oldest. Inserts are constant time and memory use is
fixed.

On chain this pattern suits "last N observations" data: recent prices for an average, recent
actions for a rate limit, or a bounded activity log. Storage that is overwritten rather than
extended also costs less gas than writing fresh slots.

## Index arithmetic

With `capacity = C` and `n` total pushes:

- next write slot: `n % C`
- number of valid elements: `min(n, C)`
- slot of logical index `i` (0 = oldest): `(n - length + i) % C`

Worked example, `C = 3`, pushes `10, 20, 30, 40`:

```
slots:  [40, 20, 30]      n = 4, length = 3
i = 0 -> (4 - 3 + 0) % 3 = 1 -> 20
i = 1 -> (4 - 3 + 1) % 3 = 2 -> 30
i = 2 -> (4 - 3 + 2) % 3 = 0 -> 40
```

## Modulo

`a % b` is the remainder of integer division and reverts with a panic when `b == 0`. This is why a
zero capacity has to be rejected in the constructor.

## Returning arrays

A view function can build a `uint256[] memory` of a size known at run time with
`new uint256[](len)` and fill it in a loop. Such a function is meant for off-chain callers and
small sizes: the gas cost grows with the number of elements.

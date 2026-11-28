# TWAP Oracle Notes

## Why cumulative prices

A spot price can be moved inside a single transaction. A time-weighted average over a
window of `n` seconds can only be moved by holding a distorted price for a meaningful part
of that window, which costs real capital for every second. Storing the integral of the price
makes the average a constant-time computation:

```
twap(t0, t1) = (cumulative(t1) - cumulative(t0)) / (t1 - t0)
```

## Ring buffers

A ring buffer of size `N` keeps the last `N` observations with one storage write per update
and no shifting. The write position advances modulo `N`; once the buffer is full each write
replaces the oldest entry. The buffer therefore covers a moving window whose length depends
on how frequently updates arrive.

## Interpolation

Between two consecutive observations the price is constant, so the cumulative value is a
straight line. The value at an arbitrary timestamp between them is found by linear
interpolation. After the newest observation the line continues with the current spot price.

## Integer widths

`uint64` holds timestamps for the lifetime of the chain. `uint192` holds the cumulative value;
with prices below `2^128` it cannot overflow in any realistic time span. Packing both into
one storage slot makes every observation a single SSTORE.

# Integer Widths and Explicit Conversions

## Widening and narrowing

Unsigned integers come in widths from `uint8` to `uint256` in steps of 8 bits.

- Converting to a **wider** type is always safe and can be implicit: `uint256 a = someUint64;`.
- Converting to a **narrower** type must be written explicitly, and the compiler performs it by
  cutting off the high-order bits:

```solidity
uint32 a = 0x12345678;
uint16 b = uint16(a);   // b == 0x5678
```

No check is inserted. This is true in every 0.8.x release; the overflow checks added in 0.8.0
cover arithmetic operators only.

## Limits of a type

`type(uintN).max` is `2**N - 1`, and `type(uintN).min` is zero. Using these expressions avoids
mistakes in long literals.

## Libraries

A library groups reusable functions. Functions marked `internal` are copied into the calling
contract at compile time. A `using L for T;` directive attaches the library's functions to values
of type `T`, with the value passed as the first argument.

Libraries may declare custom errors. From outside they are referred to as `L.ErrorName`, and
`L.ErrorName.selector` gives the four-byte identifier.

## Why narrow at all

Several small fields can share one 32-byte storage slot, which saves 20,000 gas per avoided slot
on first write. The saving is only sound when every value is proven to fit in its field before it
is stored.

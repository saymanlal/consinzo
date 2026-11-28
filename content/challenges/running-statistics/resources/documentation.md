# Incremental Aggregation: Background

## Why not store everything

Each storage slot costs gas to write, and a loop over a growing array costs more with every
element until a call no longer fits in a block. Contracts therefore keep aggregates that are
updated in constant time and leave the raw history to events, which off-chain software can read.

Statistics that can be maintained incrementally with constant state:

| statistic | update |
| --------- | ------ |
| count | `count += 1` |
| sum | `sum += value` |
| min / max | compare with the stored extreme |
| mean | derived on read: `sum / count` |

A median, by contrast, needs the full data set and does not fit this model.

## Default values and sentinels

Every storage variable starts at zero. For a running minimum that default is wrong because zero is
smaller than any real input. Either handle the first element explicitly or start from
`type(uint256).max`. Do not use a possible data value as the "nothing yet" marker.

## Integer division

`sum / count` truncates towards zero. Dividing by zero reverts with `Panic(0x12)`; guard it and
report a domain-specific error.

## Overflow

Solidity 0.8 reverts on overflow by default. For a sum of arbitrary `uint256` values that is the
correct behaviour: refusing a submission is better than reporting a wrapped total.

## Events as history

`Submitted(by, value)` records each input in the log. Anyone who needs the individual values can
reconstruct them from the events without the contract paying to store them.

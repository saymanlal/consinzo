# Swap Routers

## Why a router

Constant-product pairs are deliberately minimal: `swap` sends out what the caller asks for and
then checks that enough input arrived. They do not compute prices for the user, do not pull
tokens and know nothing about other pairs. A router is the user-facing layer that

- computes how much output a given input buys,
- moves the user's tokens into the pair,
- chains several pairs when there is no direct market, and
- protects the user against price movement and delayed inclusion.

## The pair's swap protocol

1. The input tokens are transferred to the pair.
2. `swap(amount0Out, amount1Out, to)` transfers the outputs.
3. The pair compares its balances with its stored reserves to infer the input, and requires
   that the product of the fee-adjusted balances has not decreased.

The caller is responsible for requesting an output that satisfies the check.

## Multi-hop

With a path `[A, B, C]` the output of the `A/B` swap is the input of the `B/C` swap. Since a
pair only needs its input to have arrived before `swap` is called, the first pair can send `B`
directly to the second pair.

## User protection

- **Minimum output.** Between signing and execution other trades may move the price. The user
  states the least it accepts; the router reverts below that.
- **Deadline.** A transaction can sit in the mempool for a long time. A deadline bounds how
  long the quoted minimum remains executable.

## Token ordering

Pairs store their two tokens in a canonical order (sorted by address). Everything a router
reads from or sends to a pair is expressed in that order, so each hop must translate between
"input/output" and "token0/token1".

# Reference Solution Explanation

## Nonces

`nextNonce` is a mapping from destination chain id to a counter. `deposit` reads the
counter, uses it and increments it in one expression (`nextNonce[dest]++`). A single global
counter would also make deposits unique, but each destination would then see gaps and could
not tell a missing deposit from one that went elsewhere.

The counter is never reset. Disabling and re-enabling a destination continues from where it
stopped, so an old `(destination, nonce)` pair can never be issued twice.

## Check order and atomicity

The checks run in the order the README fixes: destination, recipient, amount. State is
written before `transferFrom` is called. That is safe because any failure of the token
call, a revert or a `false` return turned into `TransferFailed()`, reverts the whole
transaction including the nonce increment. Ignoring the return value is the classic bug
here: a token that signals failure by returning `false` would produce a deposit record
with nothing locked behind it, which the destination would then pay out.

## Deposit identifier

`depositHash` uses `abi.encode`, not `abi.encodePacked`, so every field occupies a fixed
32-byte slot and no two different tuples share an encoding. The preimage starts with
`block.chainid` and `address(this)`: without them, two boxes (or the same box deployed on
two source chains) would emit colliding identifiers for deposits that are unrelated.

Because nonces are sequential, "this nonce was used" is `nonce < nextNonce[dest]`; no extra
existence flag is needed.

## Local chain

`setChainSupported` refuses `block.chainid`. A deposit addressed to the chain it is made on
can never be relayed, so the tokens would be locked for nothing.

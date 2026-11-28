# Reference Solution Explanation

## Counting attestations

The contract stores only `hasAttested[id][relayer]`. `attestationCount` loops over the
current relayer list and counts the flags that are set. A running counter per transfer
looks cheaper but is wrong as soon as the committee changes: a relayer that is removed
(for example because its key leaked) would keep contributing to every transfer it had
already attested to. Counting at execution time makes removal effective immediately and
makes threshold changes apply to pending transfers as well.

The committee is small and owner-controlled, so the loop is bounded.

## Two layers of replay protection

- `executed[id]` stops the same transfer from being paid twice.
- `nonceUsed[srcChainId][nonce]` stops a *different* transfer with the same source nonce.

The second flag matters because the id commits to recipient and amount. Without it, a
committee that attested to two versions of nonce 5, by mistake or because a majority is
compromised, could have both paid. A source nonce corresponds to one deposit, so at most
one release may ever be associated with it.

The id includes `block.chainid` and `address(this)`, so attestations collected for another
deployment or another destination chain are meaningless here.

## Rate limit

Each token has `(windowStart, spent)`. A window starts at the first execution after the
previous one expired, not on a clock-aligned boundary. `availableToRelease` and `execute`
share the same expiry rule (`block.timestamp >= start + WINDOW`), so the view always
predicts what `execute` will accept. Lowering the limit below what was already spent
yields zero rather than underflowing.

A transfer rejected by the rate limit reverts completely. Its attestations are still in
storage, so it can be retried in a later window. Consuming the nonce before the limit
check would permanently lose the user's funds.

## Order of effects

`executed`, `nonceUsed` and the window counters are written before `token.transfer`. A
token with a callback therefore sees a finished execution and a nested `execute` for the
same transfer fails with `AlreadyExecuted()`. A `false` return is converted into
`TransferFailed()`, which rolls all of it back.

## Committee management

`removeRelayer` uses swap-and-pop and refuses to shrink the set below the threshold;
otherwise the bridge would be permanently unable to reach quorum.

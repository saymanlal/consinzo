# msg.value in loops and batches

## What msg.value is

`msg.value` is the amount of wei attached to the current external call. It is fixed when the
call starts. Reading it twice returns the same number, whether the reads are in consecutive
statements, different loop iterations or different internal functions. It is also preserved
across `delegatecall`, which is why payable multicall helpers built on `delegatecall` are a
well-known source of the same bug.

## The pattern to avoid

```solidity
for (uint256 i; i < ids.length; i++) {
    require(msg.value == price[ids[i]]);   // same msg.value every time
    _deliver(ids[i]);
}
```

Each iteration believes it has been paid in full.

## The pattern to use

Compute what the whole call should cost, then compare once:

```solidity
uint256 total;
for (uint256 i; i < ids.length; i++) total += _book(ids[i]);
require(msg.value == total);
```

If you want to accept overpayment, refund `msg.value - total` explicitly and treat that
transfer as an external call (do it last).

## An invariant worth testing

For a contract that only receives ETH through sales, the sum of everything it believes it
has earned must equal its balance. Asserting `proceeds == address(this).balance` after mixed
sequences of purchases detects reuse of `msg.value`, missing refunds and double counting.

# Background: Request / Fulfil Randomness

## Why two transactions

Everything a contract can read during a transaction (`block.timestamp`, `block.prevrandao`,
balances, storage) is known to, or influenced by, whoever builds the block, and a calling
contract can revert when it dislikes the outcome. Randomness that decides anything of value
therefore comes from outside: the contract commits to a request first, and the random
value is delivered in a later transaction, so nobody knows the outcome at the moment the
request is made.

## The coordinator pattern

```
consumer ── requestRandomWords(keyHash, numWords) ──▶ coordinator      (tx 1)
consumer ◀── rawFulfillRandomWords(requestId, words) ── coordinator    (tx 2, later)
```

- The coordinator returns a `requestId`. The consumer stores what it needs to finish the
  job under that id (who asked, with which parameters).
- The callback is an ordinary external function. It must verify that `msg.sender` is the
  coordinator.
- The consumer should tolerate a callback that never arrives (timeouts) and must tolerate
  one that arrives late.

## Turning a word into a bounded value

`word % n` yields a value in `[0, n-1]`. Add 1 for a die face. One word per independent
outcome is the simple approach used here.

## State machines

Model each request with an explicit status enum and check the status at the top of every
function that advances it. The zero value of the enum should mean "does not exist".

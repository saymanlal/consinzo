# Crowdfunding Contracts: Background

## All-or-nothing funding

An all-or-nothing campaign promises backers that their money is only spent if enough other people
also commit. On-chain, the contract itself enforces that promise: funds are locked until a deadline
and then go one of two ways.

| After the deadline | Who can act | What they get |
| --- | --- | --- |
| `totalRaised >= goal` | creator, once | the whole pot |
| `totalRaised < goal` | each backer | their own contribution |

## Time in Solidity

`block.timestamp` is the timestamp of the block containing the transaction, in seconds. A deadline
is normally stored as an absolute timestamp computed once in the constructor
(`block.timestamp + duration`). Decide explicitly which side of the comparison the boundary instant
belongs to, and use the complementary comparison in the other phase so that no instant belongs to
both phases or to neither.

## Sending ETH safely

- Use `(bool ok, ) = to.call{value: amount}("")` and check `ok`.
- Update storage before the call (checks-effects-interactions). A recipient contract runs code
  when it receives ETH and may call back into your contract.
- Prefer the withdrawal pattern: let each recipient pull their own funds instead of pushing ETH to
  a list of addresses in a loop.

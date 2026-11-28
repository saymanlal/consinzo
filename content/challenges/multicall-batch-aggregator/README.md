# Multicall Aggregator with Per-Call Failure Flags

## Problem Statement

Off-chain clients often need to read or write many things in one transaction. Implement
`Multicall` in `src/Multicall.sol`: a contract that runs a list of calls in order and reports,
for every call, whether it succeeded and what it returned.

## Required Interface

```solidity
struct Call {
    address target;
    bool allowFailure;
    bytes callData;
}

struct Result {
    bool success;
    bytes returnData;
}

error TargetNotContract(uint256 index);
error CallFailed(uint256 index, bytes returnData);

function aggregate(Call[] calldata calls)
    external
    returns (uint256 blockNumber, Result[] memory results);
```

## Rules

1. Calls are executed in array order with a plain `call` (no value is forwarded). The targets
   see the `Multicall` contract as `msg.sender`.
2. `results` has exactly one entry per call, at the same index. `returnData` is the raw data
   returned by the target: the ABI-encoded return values on success, the raw revert data on
   failure.
3. If a call fails and its `allowFailure` is `false`, the whole transaction reverts with
   `CallFailed(index, returnData)`, where `returnData` is the revert data of the failed call.
4. If a call fails and its `allowFailure` is `true`, execution continues and the entry is
   `Result(false, revertData)`.
5. If `target` has no code, revert with `TargetNotContract(index)`. This applies even when
   `allowFailure` is `true`, because a low-level call to an address without code would
   otherwise be reported as a success.
6. `blockNumber` is `block.number`.
7. An empty batch returns an empty `results` array.

## What the Tests Check

- Ordering, state changes made by the calls, and the exact return data of each call.
- Both behaviours of `allowFailure`, including the revert data carried by `CallFailed`.
- Rejection of targets without code, and that a reverted batch leaves no state behind.

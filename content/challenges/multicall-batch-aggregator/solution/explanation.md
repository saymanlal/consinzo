# Reference Solution Explanation

`aggregate` walks the calls once. For each call it:

1. Rejects targets without code with `TargetNotContract(i)`. The EVM treats a call to an
   empty account as a success that returns nothing, so without this check a wrong address
   would silently be reported as `success = true`.
2. Performs `target.call(callData)` and keeps both the success flag and the raw return data.
3. Reverts with `CallFailed(i, returnData)` when the call failed and `allowFailure` is false.
   Because the whole transaction reverts, the state changes of earlier calls are undone as well.
4. Otherwise stores `Result(success, returnData)` at the same index.

## Pitfalls

- Decoding or re-encoding the return data. The caller needs the raw bytes: a custom error,
  an `Error(string)`, or nothing at all for an empty revert.
- Using `staticcall`, which makes every state-changing call fail.
- Skipping the code check when `allowFailure` is true. The flag only covers calls that fail;
  a call to an empty account does not fail.
- Using `delegatecall`, which would run foreign code against the aggregator's own storage.

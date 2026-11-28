# Reference Solution Explanation

## How the EVM call is dispatched

Solidity generates a dispatcher at the start of every contract. For an incoming call it applies
these rules in order:

1. Calldata is empty and `receive()` exists: run `receive()`.
2. The first four bytes match a function selector: run that function.
3. Otherwise run `fallback()` if it exists; if not, revert.

The reference implements both special functions, so the two paths in the problem statement map
directly onto rules 1 and 3. Nothing needs to be checked by hand; there is no `if (msg.data.length
== 0)` in the solution.

## Why both are payable

`receive()` must be `payable` by definition. `fallback()` is only able to accept value when it is
declared `payable`; without it an unknown call that carries Ether reverts, which breaks rule 2 of
the task.

## The selector

`msg.sig` is `bytes4(msg.data)` with zero padding, so calldata `0xab` is recorded as `0xab000000`.
Slicing `msg.data[0:4]` instead would revert on short calldata.

## Pitfalls

- Declaring only `fallback() external payable`. Plain transfers would then also land in
  `fallback()` and be counted as unknown calls.
- Counting inside `ping()` or `balance()`. A matched selector never reaches `fallback()`.
- Keeping one shared total. The task asks for the wei received on each path separately, while
  `contributionOf` combines both paths per sender.
- Making `ping()` payable. Ether sent to a declared non-payable function is rejected by the
  compiler-generated check, which is the desired behaviour.

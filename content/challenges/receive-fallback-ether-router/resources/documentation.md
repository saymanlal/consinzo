# receive, fallback and Call Dispatch

## The two special functions

```solidity
receive() external payable { ... }
fallback() external payable { ... }   // `payable` is optional
```

Neither has the `function` keyword, arguments or (in this form) return values. A contract can
have at most one of each.

| Calldata | `receive()` exists | Result |
| --- | --- | --- |
| empty | yes | `receive()` |
| empty | no | `fallback()` if it is payable or no value is sent, otherwise revert |
| matches a function | either | that function |
| not empty, no match | either | `fallback()`, or revert if there is none |

## Sending Ether to a contract

- `address.call{value: v}("")` sends an empty-calldata message and forwards all remaining gas.
- `transfer` and `send` also send empty calldata but forward only 2,300 gas, which is enough to
  emit an event and not enough to write storage. A `receive()` that updates counters therefore
  cannot be paid with `transfer`; callers must use `call`.

## msg.sig and msg.data

- `msg.data` is the complete calldata.
- `msg.sig` is its first four bytes as `bytes4`. Missing bytes read as zero.

## Value and non-payable functions

Every function that is not marked `payable` begins with a compiler-generated check that
`msg.value == 0`. Sending Ether to such a function reverts before any of its code runs.

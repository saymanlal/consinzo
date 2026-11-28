# Reference Solution Explanation

## Root cause

The router executed `target.call(data)` with both values chosen by the caller. In that call
`msg.sender` is the router, so every contract that trusts the router can be driven by
anyone. ERC-20 tokens trust the router in a very concrete way: users have granted it
allowances. Calling `token.transferFrom(victim, attacker, amount)` through the router spends
those allowances. The rest of `swap` does not get in the way, because the attacker can pick
a throwaway `tokenIn`, `minAmountOut = 0` and any `tokenOut`.

## Fix

```solidity
if (!allowedTarget[target]) revert TargetNotAllowed();
```

placed before the first token operation. Only exchanges the owner has reviewed can be
called, and token contracts are never added to that list. With a fixed set of exchanges,
caller-supplied `data` can at most spend the `amountIn` allowance the router grants for the
duration of the call, which is the caller's own money.

The existing allowance reset and balance-difference accounting are kept.

## Pitfalls

- Blocking only `target == tokenIn` or only the `transferFrom` selector is not enough: the
  victim's token may differ from `tokenIn`, and tokens expose other spender functions
  (`permit`-based flows, `burnFrom`, ERC-777 operators).
- Validating `data` instead of `target` is fragile; allowlisting the destination is the
  standard control.
- The allowlist is only as good as its contents. An exchange that itself forwards arbitrary
  calls must not be listed.

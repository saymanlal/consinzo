# Patch a Swap Router That Executes Arbitrary Calls

`SwapRouter` is a thin aggregation router. A user approves the router for a token once.
For each swap the router pulls `amountIn` of `tokenIn` from the user, approves the chosen
exchange, executes `target.call(data)`, and sends the `tokenOut` it received back to the
user after checking `minAmountOut`.

`target` and `data` are passed in by the caller and used as they are. The call is made by
the router, and the router is the approved spender for all of its users. An attacker can
therefore choose a token contract as `target` and
`transferFrom(victim, attacker, amount)` as `data`: the token sees the router calling
`transferFrom` with a valid allowance and moves the victim's tokens. The attacker does not
even need valuable tokens to start; any token they mint themselves works as `tokenIn`.

## Your task

Patch `src/SwapRouter.sol` so that the router only ever calls exchanges the owner has
vetted. The contract already has `allowedTarget` and `setAllowedTarget`.

## Required behaviour

`swap(tokenIn, tokenOut, amountIn, minAmountOut, target, data) returns (uint256 amountOut)`

- reverts with `ZeroAmount()` when `amountIn == 0`;
- reverts with `TargetNotAllowed()` when `allowedTarget[target]` is false. This check must
  happen before any token is pulled or approved;
- otherwise behaves as before: pulls `amountIn`, approves `target` for exactly `amountIn`,
  calls it, resets the approval to zero, reverts with `SwapCallFailed()` if the call
  failed and with `InsufficientOutput()` if less than `minAmountOut` of `tokenOut`
  arrived, then forwards the received `tokenOut` to the caller.

`setAllowedTarget(address target, bool allowed)` stays owner-only (`NotOwner()`), and
removing a target takes effect for the next swap.

After any call, the tokens and approvals of users who are not `msg.sender` must be
unchanged, and the router must hold no tokens and no outstanding allowance to the exchange.

## What the tests check

Public tests perform a normal swap through an allowlisted mock exchange, attempt the
approval drain with the token as target, try an unlisted exchange and check the minimum
output. Hidden tests repeat the drain from an attack contract that pays with a worthless
token and swallows reverts, verify that nothing moves before the allowlist check, and cover
revocation, allowlist administration, consecutive swaps and failing exchange calls.

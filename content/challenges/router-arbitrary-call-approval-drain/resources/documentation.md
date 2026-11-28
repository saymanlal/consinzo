# Arbitrary external calls from approval-holding contracts

## The confused deputy

A router, aggregator or zap contract usually holds allowances from many users. Inside any
external call it makes, it is `msg.sender`. If a caller can control where that call goes and
what it says, the caller borrows the contract's authority. The token cannot tell a
legitimate `transferFrom` issued during a swap from one crafted by a third party: in both
cases the approved spender is calling.

This pattern has caused repeated losses in production aggregators and bridges that accepted
a user-supplied "swap target" or "call data" parameter.

## What ERC-20 allowances mean

`approve(spender, amount)` lets `spender` call `transferFrom(owner, anywhere, amount)` at any
later time. Many interfaces request unlimited approvals to save gas, so a single router bug
exposes the full balance of every past user, not only people swapping at that moment.

## Controls

- **Allowlist call targets.** Maintain the set of exchanges under governance and check it
  before moving funds.
- **Never allow token contracts as targets.**
- **Pull funds from `msg.sender` only**, never from an address in calldata.
- **Scope allowances the router grants**: approve the exact amount for one call and reset
  it afterwards.
- **Measure results by balance difference** and enforce a caller-supplied minimum.

## For users

Prefer exact-amount approvals, and revoke allowances to routers you no longer use.

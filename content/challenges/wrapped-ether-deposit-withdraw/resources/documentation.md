# Wrapped Ether Background

## Why wrap Ether

Ether predates ERC-20 and has no `transfer(address,uint256)` function, no `balanceOf` and no
allowances. Protocols that want to treat every asset uniformly use a wrapper: a contract that
holds Ether and issues an ERC-20 style balance against it at a fixed 1:1 rate.

## Receiving Ether

A Solidity contract receives Ether in three ways that run code:

- a `payable` function called with `msg.value > 0`;
- `receive() external payable`, executed when calldata is empty;
- `fallback() external payable`, executed when no function matches.

Inside any of them `msg.value` is the amount sent and `msg.sender` is the immediate caller.

## Sending Ether

`(bool ok, ) = recipient.call{value: amount}("")` forwards all remaining gas and returns
`false` instead of reverting when the recipient reverts or has no payable entry point. The
caller must check `ok`. Because the recipient runs arbitrary code, state that the recipient
could exploit must be updated before the call (checks-effects-interactions).

## The backing invariant

For a wrapper to be solvent, `address(this).balance >= totalSupply` must hold at all times, and
`totalSupply` must equal the sum of balances. Deposits increase both sides by `msg.value`;
withdrawals decrease both by `amount`; transfers change neither.

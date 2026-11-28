# ERC-20 Allowances

## The approve / transferFrom flow

A holder calls `approve(spender, amount)`; the spender later calls
`transferFrom(holder, recipient, value)` any number of times while the remaining allowance
covers `value`. This is how exchanges, vaults and routers pull tokens from users.

## The approve race condition

EIP-20 itself notes the problem: because `approve` overwrites, changing a non-zero allowance to
another non-zero value lets the spender use both the old and the new allowance by ordering
transactions. The EIP suggests setting the allowance to zero first. Token libraries added
`increaseAllowance` and `decreaseAllowance`, which are not part of EIP-20 but became a widely
recognised extension. They adjust the allowance relative to its current value and so cannot be
exploited by reordering.

## Infinite approvals

Approving `type(uint256).max` is the conventional way to grant an unlimited allowance. Tokens
that follow the convention skip the allowance update in `transferFrom` when the stored value is
maximal. Besides preserving the "unlimited" meaning it saves one storage write per transfer.

## Events

`Approval(owner, spender, value)` carries the new allowance in full. Off-chain software rebuilds
the allowance table from these events, so each helper must report the resulting total.

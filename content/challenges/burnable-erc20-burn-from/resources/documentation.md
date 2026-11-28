# Burning Tokens

## What burning means

Burning permanently removes tokens from circulation. Two pieces of state change together: the
holder's balance and `totalSupply`. EIP-20 does not define a burn function, but the widely used
convention is to emit `Transfer(holder, address(0), amount)` so that indexers see the supply
decrease.

## Allowances

`approve(spender, amount)` records that `spender` may use up to `amount` of the caller's tokens.
The allowance is stored as `allowance[owner][spender]`. Every time the spender uses some of it
the stored value is reduced, so the total a spender can ever use is bounded by what was approved.

`burnFrom(account, amount)` applies the same rule to burning: the spender's allowance from
`account` is consumed, then the tokens are destroyed. Protocols use it to redeem or retire
tokens that a user has approved to them without first pulling the tokens into their own balance.

## Unlimited approvals

Many integrations approve `type(uint256).max` once. The common convention, followed by the major
token libraries, is that a maximal allowance is treated as infinite and is not decremented, which
also saves a storage write on every use.

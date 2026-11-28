# Reference Solution Explanation

## Structure

Both burn paths share one internal `_burn(account, amount)` that checks the balance, reduces the
balance and `totalSupply`, and emits `Transfer(account, address(0), amount)`. `burn` calls it
for `msg.sender`; `burnFrom` consumes allowance first and then calls it for `account`.

## burnFrom

```solidity
uint256 allowed = allowance[account][msg.sender];
if (allowed < amount) revert InsufficientAllowance();
if (allowed != type(uint256).max) allowance[account][msg.sender] = allowed - amount;
_burn(account, amount);
```

- The allowance mapping is indexed `[owner][spender]`; the owner is `account` and the spender is
  `msg.sender`. Swapping the indices lets anyone burn tokens of a holder they approved.
- The allowance check precedes the balance check, as the specification requires. If the balance
  check then fails, the revert rolls the allowance write back.
- `type(uint256).max` is treated as an unlimited approval and is not written back.
- There is no `account == msg.sender` shortcut. Keeping one code path means `burnFrom` has a
  single, auditable authorisation rule.

## Supply accounting

`totalSupply` is decremented by exactly the amount removed from the balance. Since every balance
is at most `totalSupply`, the subtraction cannot underflow once the balance check has passed.

## Pitfalls

- Burning by transferring to `address(0)` without reducing `totalSupply` leaves the reported
  supply wrong forever.
- Decrementing the allowance after `_burn` is functionally equivalent here but reports the wrong
  error when both checks would fail.
- Forgetting to decrement the allowance turns any approval into an unlimited burn right.

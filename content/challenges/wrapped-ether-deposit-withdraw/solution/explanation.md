# Reference Solution Explanation

## Design

- `deposit()` is `public payable` so that `receive()` can call it directly. Both entry points
  therefore share one code path, and `msg.sender` / `msg.value` are unchanged by the internal call.
- `totalSupply` is a stored counter rather than `address(this).balance`. Ether can be forced into
  any contract (for example through `selfdestruct`), so the balance is only a lower bound on what
  the contract holds; the counter is the exact amount owed to holders.

## Why withdraw is safe

`withdraw` follows checks-effects-interactions. The caller's balance and `totalSupply` are
reduced before the low-level `call`. If the recipient re-enters `withdraw` from its `receive`
function, the second call sees the already reduced balance and reverts with
`InsufficientBalance()`. No reentrancy guard is needed.

The result of `call` is checked. A recipient that cannot accept Ether makes the whole
transaction revert with `EthTransferFailed()`, which also rolls back the balance change, so the
user's wrapped balance is never burned without the Ether being delivered.

## Pitfalls

- Sending Ether before updating the balance allows a re-entering contract to withdraw the same
  balance repeatedly.
- Ignoring the return value of `call` silently burns tokens when the transfer fails.
- Using `transfer`/`send` (2300 gas stipend) breaks withdrawals to smart contract wallets.
- Forgetting `receive()` makes plain Ether transfers revert instead of wrapping.

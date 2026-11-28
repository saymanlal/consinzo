# Unprotected Ether Withdrawal

A withdrawal function is the most valuable target in a contract that holds ETH. If it is
`external` or `public` and has no check on `msg.sender`, the balance belongs to whoever
calls it first. Bots scan new deployments for exactly this.

## Checklist for a withdrawal function

1. **Who may call it?** Enforce the answer with a comparison against `msg.sender` at the
   top of the function.
2. **Where does the ETH go?** Prefer a stored, trusted destination over a caller-supplied
   one.
3. **How is it sent?** Use `call{value: amount}("")` and revert when it returns `false`.
4. **Is state updated before the call?** Not needed here because the whole balance leaves
   in a single call, but it matters as soon as per-user balances exist.

## Immutable owners

`address public immutable owner` is written once in the constructor and stored in the
contract code, so reading it is cheap and it can never be changed. Use a storage variable
instead when ownership must be transferable.

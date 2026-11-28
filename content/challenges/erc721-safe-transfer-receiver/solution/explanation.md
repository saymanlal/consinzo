# Reference Solution Explanation

## Structure

Three internal helpers do the work:

- `_mint` and `_transfer` contain all validation and state changes.
- `_checkReceiver(from, to, tokenId, data)` performs the acceptance check.

Each `safe*` function is "state change, then check". The two overloads differ only in the
`data` they forward.

## The receiver check

```solidity
if (to.code.length == 0) return;
try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 answer) {
    if (answer != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
} catch {
    revert UnsafeRecipient();
}
```

- `to.code.length == 0` identifies externally owned accounts, which cannot implement the hook
  and can always move the token with their key.
- `try/catch` turns a reverting recipient, or one without the function, into
  `UnsafeRecipient()`.
- The returned selector is compared explicitly. A contract with a permissive fallback that
  returns nothing, or returns some other four bytes, is not accepted.
- `operator` is `msg.sender` of the token call, not `from`; the two differ when an approved
  address or operator initiates the transfer.

## Ordering and reentrancy

The hook is an external call to an address chosen by the caller, so the token must be in a
consistent state when it runs. All writes (approval cleared, balances, owner) happen in
`_transfer` before `_checkReceiver`. Inside the hook the recipient sees itself as the owner and
may transfer the token on; the outer call then completes normally. If the check fails, the
revert undoes the state changes, so no token is ever stranded half-transferred.

Calling the hook before updating state would let the recipient re-enter while the sender is
still the recorded owner, and would also break legitimate recipients that act on the token
immediately.

## Pitfalls

- Passing `from` as the operator argument.
- Running the check in `transferFrom`: the standard specifies it only for the safe variants.
- Comparing only "call succeeded" and not the returned value.
- Treating contracts under construction as safe recipients is unavoidable (`code.length` is
  zero in a constructor); the safe transfer is a guard against mistakes, not a security boundary.

# Background: Allowance Hubs

## The problem with ERC-20 allowances

EIP-20 gives every token its own `approve` / `transferFrom` pair. Allowances have no expiry,
applications commonly ask for unlimited ones, and cleaning up means one transaction per
token and spender. A compromised or abandoned spender contract keeps its access forever.

## The hub pattern

A hub is a contract that users approve once per token. Applications no longer hold ERC-20
allowances themselves; they hold allowances *in the hub* and ask the hub to move tokens:

```
owner --ERC-20 approve(max)--> hub
owner --hub.approve(token, app, amount, expiration)--> hub
app   --hub.transferFrom(owner, to, amount, token)--> hub --token.transferFrom--> token
```

The hub can attach rules the token standard lacks: an amount ceiling, an expiry timestamp
and cheap mass revocation.

## Epoch-based revocation

Keeping a counter per `(owner, spender)` and stamping each allowance with the counter value
at grant time gives O(1) revocation of everything a spender holds: incrementing the counter
makes every older stamp invalid. The same idea appears as nonce invalidation in
signature-based systems.

## Token quirks

- EIP-20 specifies that `transferFrom` returns `bool`, but some deployed tokens return
  nothing. Robust callers use a low-level call and accept empty return data.
- Other tokens return `false` instead of reverting.
- The EVM treats a call to an address without code as successful. Check
  `address.code.length` when success is inferred from empty return data.

## Checks, effects, interactions

Any external call may run arbitrary code, including a call back into the caller. Writing
state before the call keeps the contract consistent no matter what the callee does.

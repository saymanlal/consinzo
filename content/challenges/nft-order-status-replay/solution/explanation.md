# Why the patch works

An order is a standing authorisation to move the maker's token for a price. The starter
treats it as valid for as long as the struct exists, which is forever.

The reference makes `fillOrder` enforce the state machine before anything moves:

```solidity
if (o.status != Status.Open) revert OrderNotOpen();
if (o.makerNonce != nonces[o.maker]) revert StaleNonce();
if (msg.value != o.price) revert WrongPrice();
o.status = Status.Filled;
```

- `Status.Open` is the only state in which the authorisation is live. `None` (never
  created), `Cancelled` and `Filled` all fail the same check.
- Writing `Filled` before the token transfer and the ETH payment makes the fill single-use
  even if the maker is a contract that calls back in.
- The nonce comparison is what gives `cancelAllOrders` meaning: bumping the maker's nonce
  strands every order that stored the old value.

`cancelOrder` also requires `Open`, so a filled order cannot be relabelled `Cancelled` and
the two terminal states stay terminal.

## Pitfalls

- Deleting the order on fill also blocks replay, but it erases the status the interface
  exposes (`orderStatus` must report `Filled`).
- Relying on "the maker no longer owns the token" is not replay protection. Ownership can
  return, and the approval is still in place.
- Checking the nonce at creation only is useless; it must be checked at fill time against
  the maker's current nonce.

# Reference Solution Explanation

## Storage

An allowance is `(amount: uint160, expiration: uint48, epoch: uint48)`, which fills exactly
one storage slot, keyed by `owner => token => spender`. A second mapping,
`nonces[owner][spender]`, holds the owner's current epoch for that spender.

## Two kinds of revocation

- `revoke(token, spender)` deletes one slot.
- `revokeSpender(spender)` increments the nonce. Each allowance remembers the epoch in
  which it was granted, and `_pull` refuses any allowance whose epoch is not the current
  one. That revokes an unbounded number of token allowances with a single storage write and
  without the hub having to know which tokens were ever approved.

Because the epoch is stamped per allowance, approving one token after a `revokeSpender`
makes only that token live again. Storing a single "revoked" flag per spender, or comparing
against the nonce at spend time without stamping, would either make re-approval impossible
or bring every old allowance back.

## Spending

`_pull` follows checks, effects, interactions:

1. recipient, epoch, expiry and amount checks, in the order the README fixes;
2. the finite allowance is reduced in storage;
3. only then is the token called.

A token that re-enters the hub during step 3 therefore sees the reduced allowance. If the
allowance were written after the call from a value cached before it, the inner call would
spend the same units a second time.

`type(uint160).max` means unlimited and skips the write, which also saves gas.

## Calling tokens safely

The low-level call accepts three shapes of success and nothing else:

- returns exactly 32 bytes that decode to `1`;
- returns nothing (tokens that predate the return value);
- and in both cases the target must have code. A call to an address without code succeeds
  with empty return data, which would otherwise be indistinguishable from the second case
  and let a spender "pull" a token that does not exist yet.

## Batches

`batchTransferFrom` loops over `_pull`. A revert in any entry reverts the transaction, so
atomicity needs no extra code, and entries that hit the same allowance see each other's
deductions because each one reads and writes storage.

## Pitfalls

- Using `>=` for expiry, making the allowance unusable in its final second.
- Adding to the existing amount in `approve` instead of replacing it.
- Reading the allowance once per batch and writing it back at the end.
- Letting anyone other than the owner bump the nonce or delete an allowance.

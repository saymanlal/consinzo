# Reference Solution Explanation

## State machine

Each swap goes `None -> Open -> Claimed` or `None -> Open -> Refunded`. `claim` and
`refund` both start with `state == Open`, so a swap settles once. The state is written
before funds leave the contract; a recipient that re-enters during the ETH transfer sees
`Claimed` and gets `SwapNotOpen()`.

## The timelock boundary

`claim` requires `block.timestamp < timelock` and `refund` requires
`block.timestamp >= timelock`. The two conditions are complements. If both used inclusive
comparisons there would be one block in which the recipient could claim on this chain
while the sender, having seen the preimage, front-runs with a refund, or the reverse.

The asymmetry between the two chains (the party that knows the secret gets the *longer*
timeout on the asset it gives away) is a protocol-level rule the contract cannot enforce;
the tests model it with one and two hours.

## Publishing the preimage

The second leg of an atomic swap depends on the counterparty learning the secret. The
reference emits it in `Claimed` and stores it in `preimageOf` so another contract or a
test can read it. It is stored only on a successful claim.

## Hash function

The hashlock is `sha256`, not `keccak256`. SHA-256 is available on essentially every
chain, which is why HTLC protocols use it; a swap between an EVM chain and a non-EVM chain
cannot rely on Keccak.

## Token handling

- **Received amount.** `lockToken` measures the balance before and after `transferFrom`
  and stores the difference. With a fee-on-transfer token the contract holds less than
  `amount`; paying out `amount` would be covered by tokens belonging to other swaps and
  the last swap of that token could never be settled.
- **Return values.** `_callToken` uses a low-level call and accepts either no return data
  or data that decodes to `true`. Calling through the `IERC20` interface would revert on
  tokens that return nothing, because the ABI decoder expects 32 bytes.
- **Order in `lockToken`.** The swap is stored before the token is called, and the amount
  is corrected afterwards. If the transfer fails the whole transaction reverts, so no
  half-created swap survives.

## Identifier reuse

The id commits to every parameter of the lock, and an id is rejected once it has been
used, including after settlement. Allowing reuse would let a sender re-create a swap whose
preimage is already public; the recipient field protects the funds, but refusing reuse
keeps "swap id" an unambiguous reference for off-chain watchers.

## Pitfalls

- `block.timestamp <= timelock` in `claim`.
- Sending funds to `msg.sender` instead of the stored recipient or sender.
- Marking the swap claimed after the transfer.
- Storing the requested amount for tokens.

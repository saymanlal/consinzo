# Commit-reveal and what a commitment must bind

A commit-reveal scheme hides a value during one phase and proves it in a later phase:

1. Commit: publish `H(value, salt)`.
2. Reveal: publish `value` and `salt`; everyone recomputes the hash.

The hash gives two properties. It is *hiding* (the salt prevents guessing the value) and
*binding* (the committer cannot later open it to a different value). It says nothing about
*who* is allowed to open it. On a public chain both the commitment and the eventual preimage
are visible to everyone, so a scheme that only hashes the value is transferable: whoever
copies the commitment can reuse the preimage once it is broadcast.

## Binding to context

Put every piece of context that must not be interchangeable into the preimage:

| Context | Prevents |
| --- | --- |
| committing account | another account opening a copied commitment |
| contract address | reuse of a commitment in another deployment |
| chain id (when contracts share addresses across chains) | cross-chain reuse |

Then verify with the *caller's* address at reveal time, never with an address supplied as an
argument.

## Encoding

`abi.encode` pads each field to 32 bytes, so different field tuples cannot produce the same
byte string. `abi.encodePacked` with dynamic types can, and should be avoided for hashes
that carry authorisation.

## Front-running

Transactions are visible before they are included. Any design in which the first transaction
carrying some public data wins must assume an attacker can resubmit that data with a higher
fee. Binding the data to the sender removes the incentive: the copied transaction fails.

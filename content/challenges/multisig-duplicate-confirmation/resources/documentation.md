# Threshold signatures in on-chain multisigs

## What M-of-N promises

An M-of-N wallet promises that no action happens unless M *different* key holders agree.
The security argument is about independence: an attacker has to compromise M separate keys.
Any path that lets one key count more than once reduces M without anyone noticing.

## Where double counting comes from

| Pattern | Problem |
| --- | --- |
| `count++` on every confirmation call | repeated calls by one owner |
| iterating a signature array without ordering | the same signature supplied twice |
| owner list with repeated entries | one key occupies several seats |
| counting stored confirmations of removed owners | ex-owners still vote |

The common cure is to treat confirmations as a set: a mapping from owner to flag, where the
count changes only when a flag changes. For signature arrays the usual technique is to
require strictly increasing signer addresses.

## Constructor validation

The owner set is fixed at deployment in simple wallets, so it must be validated there:
non-zero addresses, no repeats, and `1 <= threshold <= owners.length`.

## Execution

Mark the transaction executed before the external call and revert the whole call if the
target fails. The revert restores the flag, so a failed transaction stays pending instead of
being burned.

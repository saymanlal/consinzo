# Background: Committee-Attested Bridges

## Trust model

An attested (multisig) bridge trusts that fewer than `threshold` committee members are
faulty. The destination contract does not verify the source chain; it verifies that enough
committee members vouch for a specific message. Everything the contract can do to limit
damage when that assumption fails is worth doing.

## What an attestation covers

Relayers attest to a hash of the full transfer: source chain, nonce, token, recipient,
amount, plus the destination chain id and bridge address. Two relayers attesting to
different amounts for the same nonce are attesting to different messages and must not be
added together.

## Membership changes

Committees rotate. The safe rule is to evaluate quorum against the committee that exists
when the transfer is executed. Designs that add one to a counter at attestation time
freeze the old committee's votes into pending transfers.

## Replay protection

Mark a message as consumed before any external call. If messages are identified by a hash
of their contents, also consume the source-side sequence number, because the contents are
exactly what a faulty committee can vary.

## Rate limiting

A rate limit bounds the loss per unit of time when everything else has failed. The simple
form used here is a window counter per token:

```
if now >= windowStart + WINDOW: windowStart = now; spent = 0
require(spent + amount <= limit)
spent += amount
```

Transfers that do not fit must stay pending rather than being dropped.

# Background: Generalised Cross-Chain Messaging

## Roles

- **Endpoint**: the contract applications talk to on each chain. It assigns nonces,
  collects fees, and on the destination side validates and executes packets.
- **Application**: any contract. Sends with `send`, receives through a callback.
- **Relayer**: off-chain actor (trusted in this exercise) that watches `MessageSent`
  events and submits the packets to the destination endpoint.

## Ordered and unordered delivery

Some applications need messages processed in the order they were sent (a sequence of
state updates). Others only need each message exactly once (independent transfers) and
prefer that one stuck message does not hold up the rest. Endpoints therefore offer both:

- ordered: the destination tracks the last nonce and accepts only the next one;
- unordered: the destination tracks a set of seen message ids.

Each mode has its own nonce sequence so that the two cannot interfere.

## When the receiver fails

The destination endpoint cannot fix a failing application. It can only make sure the
message is not lost and that the failure stays contained:

- store the fact that the message arrived and failed;
- allow it to be executed again later;
- on ordered channels, stop the channel at that point;
- let the application explicitly discard a message it will never be able to process.

## Calling untrusted code safely

The receiver is arbitrary code running in the middle of the endpoint's transaction.
Relevant EVM facts:

- At most 63/64 of the remaining gas can be passed to a call (EIP-150). A caller of the
  endpoint controls the remaining gas and can thereby reduce what the receiver gets.
- A call to an account without code succeeds.
- Return data (including revert data) is copied by Solidity's high-level call syntax,
  and the copy is paid for by the caller.
- The callee may call back into the endpoint.

## Fees

Sending costs the relayer gas on the destination chain, so endpoints charge a fee on the
source chain, typically a base amount plus a per-byte amount. Users rarely know the exact
fee in advance and overpay; the excess is returned to an address they choose. That refund
is itself a call to untrusted code and belongs at the very end of `send`.

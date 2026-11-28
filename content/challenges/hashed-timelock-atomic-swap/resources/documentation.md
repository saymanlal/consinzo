# Background: Hashed Timelock Contracts

## The primitive

An HTLC holds funds under two conditions:

- **hashlock** – the recipient can take the funds by presenting `s` with `hash(s) == H`;
- **timelock** – after time `T` the sender can take the funds back.

## Atomic swap protocol

Alice wants to trade asset X on chain A for Bob's asset Y on chain B.

1. Alice generates a random secret `s` and computes `H = sha256(s)`.
2. Alice locks X for Bob on chain A with hashlock `H` and timelock `T_A`.
3. Bob checks Alice's lock, then locks Y for Alice on chain B with the same `H` and a
   timelock `T_B` that is clearly earlier than `T_A`.
4. Alice claims Y on chain B before `T_B`. Doing so publishes `s` on chain B.
5. Bob reads `s` and claims X on chain A before `T_A`.

If Alice never claims, Bob refunds after `T_B` and Alice after `T_A`. `T_B < T_A` matters:
Bob must have time left to use the secret after the last moment Alice can reveal it.

No message passes between the chains. The only link is the shared hash and the fact that
claiming reveals the preimage.

## Hash functions in Solidity

`sha256(bytes memory) returns (bytes32)` calls the SHA-256 precompile.
`abi.encodePacked(bytes32)` yields the 32 raw bytes, so
`sha256(abi.encodePacked(preimage))` hashes exactly the preimage.

## Tokens that do not follow the standard exactly

- Some tokens deduct a fee inside `transfer`, so the receiver gets less than `amount`.
  Compare `balanceOf(address(this))` before and after to learn what arrived.
- Some tokens return no value from `transfer` / `transferFrom`. A low-level
  `token.call(abi.encodeWithSelector(...))` lets the caller inspect the returned bytes:
  empty data or an encoded `true` means success.

## Sending ETH

`(bool ok,) = to.call{value: amount}("");` forwards control to `to`. Update contract state
first and check `ok`.

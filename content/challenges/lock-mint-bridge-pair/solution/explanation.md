# Reference Solution Explanation

## Approach

Each side keeps two pieces of bridge state: a counter that numbers its own outgoing
messages (`depositCount` on the vault, `burnCount` on the wrapped token) and a
`processed…` mapping that records which incoming messages from the other side have been
consumed. Outgoing nonces are assigned with `++counter`, so the first one is 1.

- **Replay protection is keyed by nonce only.** A second delivery with the same nonce but a
  different recipient or amount is still a replay. The nonce is marked before any token
  movement.
- **`totalLocked` is internal accounting.** `release` compares the amount with
  `totalLocked`, not with `token.balanceOf(vault)`. Tokens donated to the vault were never
  matched by a mint, so they must not make a larger release possible. This is what keeps
  `wrapped.totalSupply() == vault.totalLocked()` once every message is delivered.
- **Check order** follows the README: authorisation first, argument validation next, replay
  and solvency last. A reverted call changes no state, so a failed delivery never consumes
  a nonce.
- **Token return values.** `transfer` and `transferFrom` return a `bool`; a `false` result
  is converted to `TransferFailed()`. State is updated before the token call
  (checks-effects-interactions); a revert rolls everything back.

## Pitfalls

- Keying replay protection by `keccak256(nonce, to, amount)`: the relayer (or a bug in it)
  could then mint twice for one deposit by varying a field.
- Using the vault's token balance as the release limit.
- Starting nonces at 0, or returning the counter before incrementing it.
- Ignoring the boolean returned by the token.

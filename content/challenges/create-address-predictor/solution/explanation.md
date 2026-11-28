# Reference Solution Explanation

The address of a `CREATE` deployment is `keccak256(rlp([deployer, nonce]))[12:]`. The
solution builds the RLP bytes directly.

## Encoding the nonce

RLP integers are byte strings in big-endian order without leading zeros:

| nonce | encoding |
| --- | --- |
| `0` | `0x80` (the empty string) |
| `1 .. 0x7f` | the byte itself |
| otherwise | `0x80 + n`, then the `n` significant bytes |

`encodeNonce` counts the significant bytes with a shift loop and writes them out most
significant byte first.

## Encoding the list

The address is a 20-byte string, encoded as `0x94` (`0x80 + 20`) followed by the bytes. The
payload is `21 + len(encodedNonce)` bytes, at most 30, so the list always uses the short
form `0xc0 + payloadLength`. That gives `0xd6` for single-byte nonces and up to `0xde` for
an 8-byte nonce.

## Pitfalls

- Encoding nonce `0` as `0x00`. The integer zero is the empty string, `0x80`.
- Encoding `0x80` as the single byte `0x80`. From `0x80` upward a length prefix is needed
  (`0x8180`).
- Hard-coding the list prefix `0xd6`. It only holds for nonces below `0x80`.
- Trimming leading zero bytes of the address. Addresses are fixed-length 20-byte strings.
- Assuming a contract's first deployment uses nonce `0`. That is true for externally owned
  accounts; contracts start at nonce `1`.

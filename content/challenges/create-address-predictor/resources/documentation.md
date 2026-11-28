# CREATE Addresses and RLP

## The formula

For `CREATE` and for contract-creation transactions the new address is the low 160 bits of
`keccak256(rlp([sender, nonce]))`. The nonce is the sender's nonce before it is incremented
by the creation. For an externally owned account the first transaction has nonce 0. For a
contract the nonce counts the contracts it has created and starts at 1 (EIP-161).

`CREATE2` (EIP-1014) uses a different formula that does not involve the nonce.

## RLP in one page

RLP encodes two kinds of items: byte strings and lists of items.

Byte strings:

- a single byte in `[0x00, 0x7f]` is its own encoding;
- a string of 0 to 55 bytes is `0x80 + length` followed by the bytes;
- longer strings use `0xb7 + lengthOfLength`, the length, then the bytes.

Lists:

- if the concatenated encodings of the items are 0 to 55 bytes long, the list is
  `0xc0 + payloadLength` followed by the payload;
- longer lists use `0xf7 + lengthOfLength`, the length, then the payload.

Integers are encoded as the shortest big-endian byte string, so zero is the empty string.

## Worked example

Deployer `0x00112233445566778899aabbccddeeff00112233`, nonce `0x80`:

```
nonce   -> 81 80
address -> 94 00112233445566778899aabbccddeeff00112233
payload -> 23 bytes = 0x17
list    -> d7 94 0011...2233 81 80
```

## Nonce range

EIP-2681 limits account nonces to `2^64 - 1`, so the encoded nonce never exceeds nine
bytes and the list never needs the long form.

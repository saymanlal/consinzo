# CREATE Address Predictor with RLP Encoding

## Problem Statement

A contract deployed with the `CREATE` opcode (or by a plain deployment transaction) gets
the address

```
address = last 20 bytes of keccak256( rlp([deployer, nonce]) )
```

where `nonce` is the deployer's nonce at the time of the deployment. Implement
`CreateAddressPredictor` in `src/CreateAddressPredictor.sol`, which performs the RLP
encoding by hand and predicts such addresses.

## Required Interface

```solidity
error NonceTooHigh(uint256 nonce);

function encodeNonce(uint256 nonce) external pure returns (bytes memory);
function encodeDeployerAndNonce(address deployer, uint256 nonce) external pure returns (bytes memory);
function computeAddress(address deployer, uint256 nonce) external pure returns (address);
```

## Rules

1. `encodeNonce` returns the RLP encoding of the nonce as an integer:
   - `0` is encoded as the single byte `0x80` (the empty string),
   - `1` to `0x7f` are encoded as that single byte,
   - larger values are encoded as `0x80 + n` followed by the `n` big-endian bytes of the
     value, without leading zero bytes.
2. `encodeDeployerAndNonce` returns the RLP list `[deployer, nonce]`: a list prefix
   `0xc0 + payloadLength`, then the address as a 20-byte string (`0x94` followed by the
   20 bytes), then the encoded nonce.
3. `computeAddress` returns the last 20 bytes of the keccak256 hash of that list.
4. Account nonces are limited to 64 bits (EIP-2681). All three functions revert with
   `NonceTooHigh(nonce)` when `nonce > type(uint64).max`.
5. All functions are `pure`. No storage is needed.

## What the Tests Check

- Predictions against contracts that are really deployed in the test, for consecutive
  nonces that cross the one-byte / multi-byte boundary at `0x7f` / `0x80`.
- The exact RLP bytes for boundary nonces (`0`, `0x7f`, `0x80`, `0xff`, `0x100`, up to
  `2^64 - 1`).
- Known address vectors for large nonces that cannot be reached by deploying.
- The `NonceTooHigh` revert.

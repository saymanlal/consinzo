# EIP-2771 in Practice

## Roles

- **Transaction signer**: the user. Signs a request off chain, pays no gas.
- **Gas relay**: submits the transaction and pays for it.
- **Trusted forwarder**: a contract that checks the signer's signature and nonce, then
  calls the recipient with `abi.encodePacked(callData, signerAddress)`.
- **Recipient**: the application contract. It trusts exactly one forwarder (or a fixed
  set) and reads the signer from the calldata suffix.

## Why appending works

The ABI decoder reads arguments at fixed offsets from the start of calldata and does not
reject extra bytes at the end. The recipient's functions decode exactly as before, and the
20 extra bytes are available through `msg.data` or `calldataload`.

## The security argument

The recipient cannot verify signatures itself; it relies on the forwarder having done so.
That is safe only if the suffix is honoured for calls from the forwarder and for nobody
else. A recipient that reads the suffix unconditionally lets every caller choose their
identity.

## Reading the suffix

```solidity
// Solidity
address sender = address(bytes20(msg.data[msg.data.length - 20:]));

// Assembly
assembly { sender := shr(96, calldataload(sub(calldatasize(), 20))) }
```

`calldataload` returns 32 bytes starting at the given offset; the address is in the upper
20 bytes of that word, hence the shift by 96 bits.

## Interaction with other patterns

Contracts that `delegatecall` into themselves (for example a `multicall` function) must
take extra care: inner calls keep the outer `msg.sender` but carry attacker-chosen
calldata, which has led to real exploits when combined with EIP-2771.

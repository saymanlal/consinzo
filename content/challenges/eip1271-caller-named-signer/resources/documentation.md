# EIP-1271 and the question "whose signature is this?"

## Contract signatures

Externally owned accounts sign with a private key and are verified with `ecrecover`.
Contracts have no key. EIP-1271 gives them a voice:

```solidity
function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
// returns 0x1626ba7e when the contract accepts the hash
```

How a contract decides is its own business: a multisig checks owner signatures, a wallet may
keep a list of pre-approved hashes, a session-key module checks a temporary key.

## The two questions

Verifying any signature answers two separate questions:

1. **Validity.** Does signer S accept message M?
2. **Authority.** Is S entitled to authorise M?

`ecrecover` and `isValidSignature` answer only the first. For the second, the verifier must
derive S from the resource being spent: the owner of the tokens, the maker of the order, the
account being debited, or a delegate that this owner registered on-chain. A signer address
taken from calldata without that link is an attacker-controlled input, and writing a
contract that returns the magic value for everything takes five lines.

## Querying untrusted signers safely

- Use `staticcall`; validation must not have side effects.
- Do not let the signer's revert reason abort your function. Treat failure as "invalid".
- Require a full 32-byte word and compare it with the left-aligned magic value.
- Remember that calling an address without code succeeds with empty return data at the EVM
  level.
- Consider a gas cap if a malicious signer could grief by consuming all gas.

## What the hash must contain

The hash handed to the signer should bind the chain id, the verifying contract, the account,
every parameter of the action and a nonce. Otherwise a valid approval can be replayed
elsewhere or reused with different parameters.

## Replay through shared owners

One key often controls several contract wallets. If a wallet's `isValidSignature` simply
checks its owner's signature over the hash it is given, a signature made for wallet A also
validates for wallet B. Including the account address in the hash, as this vault does,
prevents that.

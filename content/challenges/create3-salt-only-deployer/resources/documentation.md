# CREATE, CREATE2 and "CREATE3"

## The two native creation opcodes

| opcode | address |
| --- | --- |
| `CREATE` | `keccak256(rlp([creator, nonce]))[12:]` |
| `CREATE2` | `keccak256(0xff ++ creator ++ salt ++ keccak256(initCode))[12:]` |

`CREATE` depends on a nonce that is hard to keep in sync across chains. `CREATE2` removes
the nonce but ties the address to the exact init code, including constructor arguments and
compiler metadata.

## Combining them

"CREATE3" is not an opcode (EIP-3171 proposed one; it has not been adopted). It is a pattern:

```
deployer --CREATE2(salt, fixed proxy code)--> proxy --CREATE(nonce 1, any code)--> contract
```

The proxy's address is fixed by the salt because its code is fixed. The contract's address
is fixed by the proxy's address because the nonce is always 1.

## The proxy bytecode

Init code `67 363d3d37363d34f0 3d 52 60 08 60 18 f3`:

| bytes | meaning |
| --- | --- |
| `67 <8 bytes>` | PUSH8 the runtime code |
| `3d` | RETURNDATASIZE, pushes 0 cheaply |
| `52` | MSTORE at 0 (the code sits in the last 8 bytes of the word) |
| `60 08 60 18 f3` | RETURN 8 bytes from offset 24 |

Runtime code `36 3d 3d 37 36 3d 34 f0`:

| bytes | meaning |
| --- | --- |
| `36 3d 3d 37` | CALLDATACOPY(0, 0, CALLDATASIZE) |
| `36 3d 34 f0` | CREATE(CALLVALUE, 0, CALLDATASIZE) |

Execution then runs off the end of the code, which is a successful stop.

## Costs and caveats

- Each deployment pays for two creations (about 55,000 gas more than plain CREATE2).
- A failed `CREATE` does not revert its caller. Always verify the result.
- On chains where `SELFDESTRUCT` still removes code, a destroyed contract can be
  re-created at the same address with different code. After EIP-6780 that is only possible
  within the creating transaction.

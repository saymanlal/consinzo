# Multicall Notes

## Low-level calls

`address.call(bytes)` returns `(bool success, bytes memory returnData)` and never reverts by
itself. `returnData` holds the ABI-encoded return values on success and the revert data on
failure. Revert data is one of:

- empty (`revert()` in assembly, out of gas, a failed `require` without a message),
- `Error(string)` with selector `0x08c379a0`,
- `Panic(uint256)` with selector `0x4e487b71`,
- a custom error: 4-byte selector followed by ABI-encoded arguments.

## Calls to accounts without code

High-level Solidity calls check `extcodesize` first and revert when the target has no code.
Low-level calls do not: the EVM executes zero instructions and reports success. Any contract
that relays arbitrary calls has to decide what to do about this case.

## Who is `msg.sender`

The targets of a multicall see the aggregator as `msg.sender`, not the original caller. A
multicall is therefore suited to reads and to calls that do not depend on the caller's
identity.

# Reference Solution Explanation

## Locations

```
location(id) = keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
```

- The inner hash maps the id to a number.
- Subtracting one yields a value whose keccak preimage is unknown, so the outer hash input
  cannot coincide with the `keccak256(key . slot)` inputs Solidity uses for mappings.
- The outer hash moves the location to the same "hashed" region where mapping entries and
  dynamic arrays live, which never overlaps the sequential slots at the start.
- Clearing the last byte aligns the struct to a multiple of 256, which helps with future
  storage models that group nearby slots.

The two locations are written as literal constants (inline assembly only accepts literal
constants) and re-derived in the constructor with `assert`, so a wrong literal cannot be
deployed.

## Storage pointers

```solidity
function _counter() private pure returns (CounterStorage storage $) {
    assembly { $.slot := COUNTER_LOCATION }
}
```

All state access goes through `_ownable()` and `_counter()`. The compiler lays the struct
members out from the base slot exactly as it would lay out contract variables from slot 0.
The contract declares no state variables, so slots 0, 1, 2, ... remain free for a proxy.

## Module logic

- `initialize` uses `owner != address(0)` as the initialised flag. That is sound because no
  function can set the owner back to zero.
- `acceptOwnership` compares `msg.sender` with `pendingOwner`. With nothing pending the
  comparison is against the zero address and fails for every caller.
- `increment` checks `limit != 0 && total >= limit`, using `>=` so that a limit lowered
  below the current total still blocks.

## Pitfalls

- Using `keccak256(bytes(id))` directly, or forgetting the `- 1` or the mask. The slots
  then differ from what ERC-7201 tooling expects.
- Declaring a helper state variable such as `bool initialized` at contract level. It lands
  in slot 0 and overwrites the proxy's implementation address.
- Returning a `memory` copy of the struct from the accessor and writing to the copy.
- Reordering struct members later. Members may only be appended.

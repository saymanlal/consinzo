# Reference Solution Explanation

## Diamond storage

All of the diamond's own state is one struct at `keccak256("consinzo.diamond.storage")`:

```solidity
struct SelectorInfo { address facet; uint32 index; }
struct DiamondStorage {
    address owner;
    mapping(bytes4 => SelectorInfo) selectors;      // routing table + position
    mapping(address => bytes4[]) facetSelectors;    // loupe: selectors per facet
    mapping(address => uint256) facetIndexPlusOne;  // position in facetList, 0 = absent
    address[] facetList;                            // loupe: facets with >= 1 selector
}
```

Facets run with `delegatecall` and can write anywhere. Keeping the routing table at a
hashed slot means a facet with ordinary state variables cannot overwrite it.

## Adding and removing in O(1)

`_addSelector` appends to the facet's selector list and records the index. If the list was
empty, the facet is appended to `facetList`.

`_removeSelector` uses swap-and-pop twice:

1. In the facet's selector list: move the last selector into the freed position and
   **update the moved selector's stored index**, then pop.
2. If the list is now empty, do the same in `facetList` and update the moved facet's
   `facetIndexPlusOne`.

Forgetting either index update produces a diamond that works until the moved element is
itself removed, at which point the wrong entry is deleted. The hidden tests remove in
exactly that order.

Replace is "remove from the old facet, add to the new one", after checking that the
selector exists and is not already on the target facet.

## Immutable functions

The seven built-in functions are real Solidity functions of the diamond, so the compiler's
dispatcher handles them before the fallback is considered. A facet function with the same
selector could never be reached; `Add` and `Replace` therefore reject those selectors with
`ImmutableFunction`. They are not part of the routing table, so `Remove` reports them as
`SelectorNotFound`.

## Initialisation

After the cuts and the event, `init.delegatecall(data)` runs initialisation code in the
diamond's storage. Failure reverts the whole `diamondCut`, bubbling the callee's revert
data, or `InitFailed()` when there is none. Checking `init.code.length` first matters: a
delegatecall to an address without code succeeds and would silently skip initialisation.

## Pitfalls

- Checking the facet's code for `Remove` (the facet address must be zero there).
- Leaving an emptied facet in `facetAddresses()`, or listing a facet twice.
- Applying cuts with an internal `try`-like structure so that partial changes survive.
- Returning from the fallback without forwarding return data.

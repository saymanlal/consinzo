# Diamonds (EIP-2535)

## Motivation

- **Size**: a contract's runtime code is limited to 24,576 bytes. A diamond spreads its
  functions over any number of facets behind one address.
- **Granular upgrades**: single functions can be added, replaced or removed.
- **One address, one storage**: all facets operate on the diamond's storage.

## Vocabulary

| term | meaning |
| --- | --- |
| diamond | the proxy contract users call |
| facet | a contract whose functions the diamond delegate-calls |
| selector | first four bytes of `keccak256("name(types)")`, identifies a function |
| diamondCut | the function that changes the selector-to-facet mapping |
| loupe | the four view functions that expose the mapping |
| immutable function | a function implemented in the diamond itself; cannot be replaced |

## The cut

```solidity
struct FacetCut { address facetAddress; FacetCutAction action; bytes4[] functionSelectors; }
function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata data) external;
```

`Add` requires unused selectors, `Replace` requires selectors that exist on a different
facet, `Remove` requires existing selectors and a zero facet address. After the cuts,
`init` is delegate-called with `data`, which lets an upgrade migrate or initialise state
in the same transaction.

## Storage for facets

Because every facet shares the diamond's storage, facets must not use plain state
variables carelessly. Two conventions are common:

- *Diamond storage*: each facet (or feature) defines a struct at
  `keccak256("some.unique.string")`.
- *ERC-7201 namespaces*: the same idea with a standard formula and annotation.

The diamond's own bookkeeping uses the same technique.

## Data structures for the loupe

The standard requires that the mapping can be enumerated on chain. A typical layout keeps
a selector array per facet plus a facet array, and stores the position of each element so
that removal is constant time. An alternative packs all selectors into one array and
derives the loupe results by scanning, which is cheaper to cut and more expensive to read.

## Security notes

- `diamondCut` is the most powerful function of the system; its access control decides
  the security of everything else.
- A `delegatecall` to an address without code succeeds. Always check code size for facets
  and for `init`.
- Selector clashes between facets are impossible by construction (a selector maps to one
  facet), but two different function signatures can share a selector. `Add` will reject
  the second one.

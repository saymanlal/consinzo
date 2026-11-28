# Minimal Diamond Proxy (EIP-2535): diamondCut, Routing and Loupe

## Problem Statement

A diamond is a proxy with many implementation contracts, called *facets*. Each 4-byte
function selector is mapped to the facet that implements it; the diamond's fallback
delegate-calls that facet. The mapping is changed with `diamondCut` and inspected with the
*loupe* functions. This removes the 24 KB contract size limit and lets a system be
upgraded one function at a time.

Implement `Diamond` in `src/Diamond.sol`.

## Required Interface

```solidity
enum FacetCutAction { Add, Replace, Remove }

struct FacetCut {
    address facetAddress;
    FacetCutAction action;
    bytes4[] functionSelectors;
}

struct Facet {
    address facetAddress;
    bytes4[] functionSelectors;
}

error NotOwner();
error ZeroAddress();
error NoSelectors();
error FacetHasNoCode(address facet);
error SelectorAlreadyExists(bytes4 selector);
error SelectorNotFound(bytes4 selector);
error SameFacet(bytes4 selector);
error RemoveFacetAddressMustBeZero();
error ImmutableFunction(bytes4 selector);
error FunctionNotFound(bytes4 selector);
error InitHasNoCode(address init);
error InitFailed();

event DiamondCut(FacetCut[] cuts, address init, bytes data);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

constructor(address owner_);

function owner() external view returns (address);
function transferOwnership(address newOwner) external;

function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata data) external;

function facets() external view returns (Facet[] memory);
function facetFunctionSelectors(address facet) external view returns (bytes4[] memory);
function facetAddresses() external view returns (address[] memory);
function facetAddress(bytes4 selector) external view returns (address);

fallback() external payable;
receive() external payable;
```

## Rules

### Built-in functions

The seven functions above (`owner`, `transferOwnership`, `diamondCut` and the four loupe
functions) are implemented by the diamond itself. They are *immutable functions*: they are
not registered in the selector mapping, do not appear in the loupe results, and
`facetAddress` returns `address(0)` for them.

### Ownership

The constructor sets the owner (`ZeroAddress()` for zero). `transferOwnership` is owner
only (`NotOwner()`) and rejects the zero address.

### diamondCut

Owner only. The cuts are applied in order; within a cut the selectors are processed in
order. Any failure reverts the whole call.

For every cut:

- an empty `functionSelectors` array reverts with `NoSelectors()`.
- **Add**: `facetAddress` must have code (`FacetHasNoCode(facet)`). For each selector:
  a built-in selector reverts with `ImmutableFunction(selector)`; a selector that is
  already registered reverts with `SelectorAlreadyExists(selector)`; otherwise it is
  registered for the facet.
- **Replace**: `facetAddress` must have code. For each selector: a built-in selector
  reverts with `ImmutableFunction(selector)`; an unregistered selector reverts with
  `SelectorNotFound(selector)`; a selector already registered for this same facet reverts
  with `SameFacet(selector)`; otherwise it is moved to the new facet.
- **Remove**: `facetAddress` must be `address(0)` (`RemoveFacetAddressMustBeZero()`). For
  each selector: an unregistered selector (which includes the built-in ones) reverts with
  `SelectorNotFound(selector)`; otherwise it is unregistered.

After all cuts, `DiamondCut` is emitted. Then, if `init` is not the zero address: `init`
must have code (`InitHasNoCode(init)`) and `data` is delegate-called on it. If that call
fails, the revert data is passed on; if it failed without revert data, revert with
`InitFailed()`. If `init` is the zero address, `data` is ignored.

### Loupe

- `facetAddress(selector)`: the facet registered for the selector, or `address(0)`.
- `facetFunctionSelectors(facet)`: all selectors registered for the facet (any order),
  empty for unknown facets.
- `facetAddresses()`: every facet that currently has at least one selector, each exactly
  once (any order). A facet that lost its last selector is not listed.
- `facets()`: one entry per address in `facetAddresses()` with its selectors.

### Routing

- The fallback looks up `msg.sig`. If no facet is registered it reverts with
  `FunctionNotFound(msg.sig)`. Otherwise it delegate-calls the facet with the full
  calldata and passes return data or revert data through unchanged.
- `receive()` accepts plain ether transfers.

### Storage

Facets execute in the diamond's storage and may use any slots, including slot 0. The
diamond must keep its own state at a hashed location so that facets using sequential
slots do not corrupt it.

## What the Tests Check

- Routing, state shared between facets, `msg.sender` and value passing through.
- Every revert condition of `diamondCut` with its exact error and argument.
- Loupe consistency after long add / replace / remove sequences, including removal from
  the middle of selector lists and facets that become empty.
- Initialisation in the diamond's context, bubbling of its revert data, and atomicity.
- That a facet writing to the low storage slots does not disturb the diamond.

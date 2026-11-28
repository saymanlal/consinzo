// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Diamond {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

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

    // TODO: define a storage struct for the owner and the selector / facet bookkeeping and
    //       place it at a hashed slot. Do not declare ordinary state variables.

    constructor(address owner_) {
        // TODO
    }

    function owner() external view returns (address) {
        // TODO
        return address(0);
    }

    function transferOwnership(address newOwner) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata data) external {
        // TODO: owner only; apply Add / Replace / Remove; emit DiamondCut; run the initialiser.
        revert("NOT_IMPLEMENTED");
    }

    function facets() external view returns (Facet[] memory) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function facetAddresses() external view returns (address[] memory) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function facetAddress(bytes4 selector) external view returns (address) {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    fallback() external payable {
        // TODO: route msg.sig to its facet with delegatecall, FunctionNotFound otherwise.
        revert("NOT_IMPLEMENTED");
    }

    receive() external payable {}
}

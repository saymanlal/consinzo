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

    struct SelectorInfo {
        address facet; // address(0) means "not registered"
        uint32 index; // position inside facetSelectors[facet]
    }

    struct DiamondStorage {
        address owner;
        mapping(bytes4 => SelectorInfo) selectors;
        mapping(address => bytes4[]) facetSelectors;
        // Position of a facet in facetList plus one; zero means "not listed".
        mapping(address => uint256) facetIndexPlusOne;
        address[] facetList;
    }

    // All state of the diamond itself lives here, far away from the sequential slots that
    // facets are free to use.
    bytes32 private constant DIAMOND_STORAGE_SLOT = keccak256("consinzo.diamond.storage");

    function _ds() private pure returns (DiamondStorage storage ds) {
        bytes32 slot = DIAMOND_STORAGE_SLOT;
        assembly {
            ds.slot := slot
        }
    }

    modifier onlyOwner() {
        if (msg.sender != _ds().owner) revert NotOwner();
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        _ds().owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    // ------------------------------------------------------------------- ownership

    function owner() external view returns (address) {
        return _ds().owner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        DiamondStorage storage ds = _ds();
        emit OwnershipTransferred(ds.owner, newOwner);
        ds.owner = newOwner;
    }

    // ------------------------------------------------------------------ diamondCut

    function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata data) external onlyOwner {
        DiamondStorage storage ds = _ds();

        for (uint256 i = 0; i < cuts.length; ++i) {
            FacetCut calldata cut = cuts[i];
            bytes4[] calldata selectors = cut.functionSelectors;
            if (selectors.length == 0) revert NoSelectors();

            if (cut.action == FacetCutAction.Remove) {
                if (cut.facetAddress != address(0)) revert RemoveFacetAddressMustBeZero();
                for (uint256 j = 0; j < selectors.length; ++j) {
                    if (ds.selectors[selectors[j]].facet == address(0)) revert SelectorNotFound(selectors[j]);
                    _removeSelector(ds, selectors[j]);
                }
                continue;
            }

            address facet = cut.facetAddress;
            if (facet.code.length == 0) revert FacetHasNoCode(facet);

            for (uint256 j = 0; j < selectors.length; ++j) {
                bytes4 selector = selectors[j];
                // A registered copy of a built-in selector could never be reached, because
                // the compiler's dispatcher handles those selectors before the fallback.
                if (_isImmutable(selector)) revert ImmutableFunction(selector);

                address current = ds.selectors[selector].facet;
                if (cut.action == FacetCutAction.Add) {
                    if (current != address(0)) revert SelectorAlreadyExists(selector);
                } else {
                    if (current == address(0)) revert SelectorNotFound(selector);
                    if (current == facet) revert SameFacet(selector);
                    _removeSelector(ds, selector);
                }
                _addSelector(ds, facet, selector);
            }
        }

        emit DiamondCut(cuts, init, data);

        if (init != address(0)) {
            if (init.code.length == 0) revert InitHasNoCode(init);
            (bool ok, bytes memory ret) = init.delegatecall(data);
            if (!ok) {
                if (ret.length == 0) revert InitFailed();
                assembly {
                    revert(add(ret, 0x20), mload(ret))
                }
            }
        }
    }

    function _isImmutable(bytes4 selector) private pure returns (bool) {
        return selector == this.diamondCut.selector || selector == this.facets.selector
            || selector == this.facetFunctionSelectors.selector || selector == this.facetAddresses.selector
            || selector == this.facetAddress.selector || selector == this.owner.selector
            || selector == this.transferOwnership.selector;
    }

    function _addSelector(DiamondStorage storage ds, address facet, bytes4 selector) private {
        bytes4[] storage list = ds.facetSelectors[facet];
        if (list.length == 0) {
            // First selector of this facet: start listing the facet.
            ds.facetList.push(facet);
            ds.facetIndexPlusOne[facet] = ds.facetList.length;
        }
        ds.selectors[selector] = SelectorInfo({facet: facet, index: uint32(list.length)});
        list.push(selector);
    }

    /// Caller guarantees that `selector` is registered.
    function _removeSelector(DiamondStorage storage ds, bytes4 selector) private {
        SelectorInfo memory info = ds.selectors[selector];
        bytes4[] storage list = ds.facetSelectors[info.facet];

        // Swap with the last selector of the facet, then pop. The moved selector's stored
        // index has to follow it, otherwise a later removal corrupts the list.
        uint256 last = list.length - 1;
        if (info.index != last) {
            bytes4 moved = list[last];
            list[info.index] = moved;
            ds.selectors[moved].index = info.index;
        }
        list.pop();
        delete ds.selectors[selector];

        if (list.length == 0) {
            // The facet has no selectors left: remove it from the facet list the same way.
            uint256 index = ds.facetIndexPlusOne[info.facet] - 1;
            uint256 lastFacet = ds.facetList.length - 1;
            if (index != lastFacet) {
                address movedFacet = ds.facetList[lastFacet];
                ds.facetList[index] = movedFacet;
                ds.facetIndexPlusOne[movedFacet] = index + 1;
            }
            ds.facetList.pop();
            delete ds.facetIndexPlusOne[info.facet];
        }
    }

    // ----------------------------------------------------------------------- loupe

    function facets() external view returns (Facet[] memory result) {
        DiamondStorage storage ds = _ds();
        uint256 count = ds.facetList.length;
        result = new Facet[](count);
        for (uint256 i = 0; i < count; ++i) {
            address facet = ds.facetList[i];
            result[i] = Facet({facetAddress: facet, functionSelectors: ds.facetSelectors[facet]});
        }
    }

    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory) {
        return _ds().facetSelectors[facet];
    }

    function facetAddresses() external view returns (address[] memory) {
        return _ds().facetList;
    }

    function facetAddress(bytes4 selector) external view returns (address) {
        return _ds().selectors[selector].facet;
    }

    // --------------------------------------------------------------------- routing

    fallback() external payable {
        address facet = _ds().selectors[msg.sig].facet;
        if (facet == address(0)) revert FunctionNotFound(msg.sig);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

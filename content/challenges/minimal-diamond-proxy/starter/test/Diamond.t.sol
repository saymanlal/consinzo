// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Diamond.sol";

/// Facet with namespaced storage.
contract CounterFacet {
    struct CounterStorage {
        uint256 count;
        address lastCaller;
        uint256 received;
    }

    function _s() internal pure returns (CounterStorage storage s) {
        bytes32 slot = keccak256("test.counter.facet");
        assembly {
            s.slot := slot
        }
    }

    function increment() external payable virtual {
        CounterStorage storage s = _s();
        s.count += 1;
        s.lastCaller = msg.sender;
        s.received += msg.value;
    }

    function count() external view returns (uint256) {
        return _s().count;
    }

    function lastCaller() external view returns (address) {
        return _s().lastCaller;
    }

    function received() external view returns (uint256) {
        return _s().received;
    }
}

contract CounterFacetV2 is CounterFacet {
    function increment() external payable override {
        CounterStorage storage s = _s();
        s.count += 10;
        s.lastCaller = msg.sender;
        s.received += msg.value;
    }
}

/// Facet that uses the sequential slots 0..3, as a carelessly written facet would.
contract SequentialFacet {
    error Refused(uint256 code);

    uint256 internal a; // slot 0
    uint256 internal b; // slot 1
    address internal c; // slot 2
    bytes32 internal d; // slot 3

    function fillLowSlots(uint256 value) external {
        a = value;
        b = value;
        c = address(uint160(value));
        d = bytes32(value);
    }

    function lowSlotSum() external view returns (uint256) {
        return a + b;
    }

    function refuse(uint256 code) external pure {
        revert Refused(code);
    }

    function echo(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }
}

/// Initialiser: executed with delegatecall from diamondCut.
contract DiamondInit {
    error InitRefused();

    function init(uint256 startCount) external {
        bytes32 slot = keccak256("test.counter.facet");
        assembly {
            sstore(slot, startCount)
        }
    }

    function fail() external pure {
        revert InitRefused();
    }

    function failSilently() external pure {
        assembly {
            revert(0, 0)
        }
    }
}

abstract contract DiamondHelpers is Test {
    Diamond public diamond;

    function _one(bytes4 a) internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = a;
    }

    function _counterSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](4);
        s[0] = CounterFacet.increment.selector;
        s[1] = CounterFacet.count.selector;
        s[2] = CounterFacet.lastCaller.selector;
        s[3] = CounterFacet.received.selector;
    }

    function _sequentialSelectors() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](4);
        s[0] = SequentialFacet.fillLowSlots.selector;
        s[1] = SequentialFacet.lowSlotSum.selector;
        s[2] = SequentialFacet.refuse.selector;
        s[3] = SequentialFacet.echo.selector;
    }

    function _single(address facet, Diamond.FacetCutAction action, bytes4[] memory selectors)
        internal
        pure
        returns (Diamond.FacetCut[] memory cuts)
    {
        cuts = new Diamond.FacetCut[](1);
        cuts[0] = Diamond.FacetCut({facetAddress: facet, action: action, functionSelectors: selectors});
    }

    function _cut(address facet, Diamond.FacetCutAction action, bytes4[] memory selectors) internal {
        diamond.diamondCut(_single(facet, action, selectors), address(0), "");
    }

    function _contains(bytes4[] memory list, bytes4 x) internal pure returns (bool) {
        for (uint256 i = 0; i < list.length; i++) if (list[i] == x) return true;
        return false;
    }

    function _containsAddress(address[] memory list, address x) internal pure returns (bool) {
        for (uint256 i = 0; i < list.length; i++) if (list[i] == x) return true;
        return false;
    }

    /// Asserts that `facet` is listed with exactly the selectors in `expected` (any order).
    function _assertFacet(address facet, bytes4[] memory expected) internal view {
        bytes4[] memory actual = diamond.facetFunctionSelectors(facet);
        assertEq(actual.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertTrue(_contains(actual, expected[i]));
            assertEq(diamond.facetAddress(expected[i]), facet);
        }
        assertEq(_containsAddress(diamond.facetAddresses(), facet), expected.length > 0);
    }
}

contract DiamondTest is DiamondHelpers {
    CounterFacet public counterFacet;
    CounterFacetV2 public counterFacetV2;
    SequentialFacet public sequentialFacet;
    address public alice = address(0xA11CE);

    function setUp() public {
        diamond = new Diamond(address(this));
        counterFacet = new CounterFacet();
        counterFacetV2 = new CounterFacetV2();
        sequentialFacet = new SequentialFacet();
    }

    function testOwnerAndEmptyLoupe() public view {
        assertEq(diamond.owner(), address(this));
        assertEq(diamond.facetAddresses().length, 0);
        assertEq(diamond.facets().length, 0);
        assertEq(diamond.facetAddress(CounterFacet.increment.selector), address(0));
    }

    function testAddFacetAndRoute() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());

        CounterFacet app = CounterFacet(address(diamond));
        vm.prank(alice);
        app.increment();
        app.increment();
        assertEq(app.count(), 2);
        assertEq(app.lastCaller(), address(this));
        // State lives in the diamond, not in the facet.
        assertEq(counterFacet.count(), 0);
    }

    function testLoupeAfterAdd() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        _cut(address(sequentialFacet), Diamond.FacetCutAction.Add, _sequentialSelectors());

        assertEq(diamond.facetAddresses().length, 2);
        _assertFacet(address(counterFacet), _counterSelectors());
        _assertFacet(address(sequentialFacet), _sequentialSelectors());

        Diamond.Facet[] memory all = diamond.facets();
        assertEq(all.length, 2);
        for (uint256 i = 0; i < 2; i++) {
            assertEq(all[i].functionSelectors.length, 4);
            assertTrue(
                all[i].facetAddress == address(counterFacet) || all[i].facetAddress == address(sequentialFacet)
            );
        }
        assertTrue(all[0].facetAddress != all[1].facetAddress);
    }

    function testReplaceSwitchesImplementationAndKeepsState() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        CounterFacet app = CounterFacet(address(diamond));
        app.increment();

        _cut(address(counterFacetV2), Diamond.FacetCutAction.Replace, _one(CounterFacet.increment.selector));
        app.increment();
        assertEq(app.count(), 11);
        assertEq(diamond.facetAddress(CounterFacet.increment.selector), address(counterFacetV2));
        assertEq(diamond.facetAddress(CounterFacet.count.selector), address(counterFacet));
    }

    function testRemoveMakesFunctionUnavailable() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(CounterFacet.increment.selector));

        assertEq(diamond.facetAddress(CounterFacet.increment.selector), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Diamond.FunctionNotFound.selector, CounterFacet.increment.selector)
        );
        CounterFacet(address(diamond)).increment();
        assertEq(CounterFacet(address(diamond)).count(), 0);
    }

    function testOnlyOwnerCanCut() public {
        Diamond.FacetCut[] memory cuts =
            _single(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        vm.prank(alice);
        vm.expectRevert(Diamond.NotOwner.selector);
        diamond.diamondCut(cuts, address(0), "");
    }

    function testAddingExistingSelectorReverts() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        Diamond.FacetCut[] memory cuts =
            _single(address(counterFacetV2), Diamond.FacetCutAction.Add, _one(CounterFacet.count.selector));
        vm.expectRevert(abi.encodeWithSelector(Diamond.SelectorAlreadyExists.selector, CounterFacet.count.selector));
        diamond.diamondCut(cuts, address(0), "");
    }
}

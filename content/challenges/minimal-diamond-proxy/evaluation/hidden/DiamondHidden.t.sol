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

contract DiamondHiddenTest is DiamondHelpers {
    CounterFacet public counterFacet;
    CounterFacetV2 public counterFacetV2;
    SequentialFacet public sequentialFacet;
    DiamondInit public initializer;
    address public alice = address(0xA11CE);

    function setUp() public {
        diamond = new Diamond(address(this));
        counterFacet = new CounterFacet();
        counterFacetV2 = new CounterFacetV2();
        sequentialFacet = new SequentialFacet();
        initializer = new DiamondInit();
    }

    function _expectCutRevert(Diamond.FacetCut[] memory cuts, bytes memory err) internal {
        vm.expectRevert(err);
        diamond.diamondCut(cuts, address(0), "");
    }

    function testHiddenLowSlotWritesDoNotCorruptDiamond() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        _cut(address(sequentialFacet), Diamond.FacetCutAction.Add, _sequentialSelectors());

        SequentialFacet(address(diamond)).fillLowSlots(type(uint256).max);
        SequentialFacet(address(diamond)).fillLowSlots(0xdeadbeef);

        assertEq(diamond.owner(), address(this));
        assertEq(diamond.facetAddresses().length, 2);
        _assertFacet(address(counterFacet), _counterSelectors());
        _assertFacet(address(sequentialFacet), _sequentialSelectors());
        CounterFacet(address(diamond)).increment();
        assertEq(CounterFacet(address(diamond)).count(), 1);
        assertEq(SequentialFacet(address(diamond)).lowSlotSum(), 2 * 0xdeadbeef);
        // Still able to cut afterwards.
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(SequentialFacet.echo.selector));
    }

    function testHiddenRemoveFromMiddleKeepsBookkeepingConsistent() public {
        bytes4[] memory all = _counterSelectors();
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, all);

        // Remove the first selector: the last one is moved into its place.
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(all[0]));
        bytes4[] memory expected = new bytes4[](3);
        expected[0] = all[1];
        expected[1] = all[2];
        expected[2] = all[3];
        _assertFacet(address(counterFacet), expected);

        // Now remove the selector that was moved, then one more.
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(all[3]));
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(all[1]));
        _assertFacet(address(counterFacet), _one(all[2]));
        assertEq(diamond.facetAddress(all[0]), address(0));
        assertEq(diamond.facetAddress(all[1]), address(0));
        assertEq(diamond.facetAddress(all[3]), address(0));

        // Re-add one and remove everything.
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _one(all[0]));
        bytes4[] memory rest = new bytes4[](2);
        rest[0] = all[2];
        rest[1] = all[0];
        _cut(address(0), Diamond.FacetCutAction.Remove, rest);
        assertEq(diamond.facetAddresses().length, 0);
        assertEq(diamond.facetFunctionSelectors(address(counterFacet)).length, 0);
        assertEq(diamond.facets().length, 0);
    }

    function testHiddenFacetListSwapAndPop() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _one(CounterFacet.count.selector));
        _cut(address(sequentialFacet), Diamond.FacetCutAction.Add, _sequentialSelectors());
        _cut(address(counterFacetV2), Diamond.FacetCutAction.Add, _one(CounterFacet.increment.selector));
        assertEq(diamond.facetAddresses().length, 3);

        // Removing the first facet moves the last one into its place.
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(CounterFacet.count.selector));
        address[] memory list = diamond.facetAddresses();
        assertEq(list.length, 2);
        assertTrue(_containsAddress(list, address(sequentialFacet)));
        assertTrue(_containsAddress(list, address(counterFacetV2)));
        assertFalse(_containsAddress(list, address(counterFacet)));

        // Removing the moved facet must work and leave exactly the other one.
        _cut(address(0), Diamond.FacetCutAction.Remove, _one(CounterFacet.increment.selector));
        list = diamond.facetAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], address(sequentialFacet));

        // A facet that comes back is listed once.
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        assertEq(diamond.facetAddresses().length, 2);
        _assertFacet(address(counterFacet), _counterSelectors());
        Diamond.Facet[] memory all = diamond.facets();
        assertEq(all.length, 2);
        assertEq(all[0].functionSelectors.length, 4);
        assertEq(all[1].functionSelectors.length, 4);
    }

    function testHiddenReplaceMovesSelectorsBetweenFacets() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());

        // Replace all four: the old facet must disappear from the loupe.
        _cut(address(counterFacetV2), Diamond.FacetCutAction.Replace, _counterSelectors());
        _assertFacet(address(counterFacetV2), _counterSelectors());
        assertEq(diamond.facetFunctionSelectors(address(counterFacet)).length, 0);
        address[] memory list = diamond.facetAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], address(counterFacetV2));

        CounterFacet(address(diamond)).increment();
        assertEq(CounterFacet(address(diamond)).count(), 10);

        // Replace one back.
        _cut(address(counterFacet), Diamond.FacetCutAction.Replace, _one(CounterFacet.increment.selector));
        CounterFacet(address(diamond)).increment();
        assertEq(CounterFacet(address(diamond)).count(), 11);
        assertEq(diamond.facetAddresses().length, 2);
        assertEq(diamond.facetFunctionSelectors(address(counterFacetV2)).length, 3);
        _assertFacet(address(counterFacet), _one(CounterFacet.increment.selector));
    }

    function testHiddenReplaceErrors() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _one(CounterFacet.count.selector));

        _expectCutRevert(
            _single(address(counterFacet), Diamond.FacetCutAction.Replace, _one(CounterFacet.count.selector)),
            abi.encodeWithSelector(Diamond.SameFacet.selector, CounterFacet.count.selector)
        );
        _expectCutRevert(
            _single(address(counterFacetV2), Diamond.FacetCutAction.Replace, _one(CounterFacet.increment.selector)),
            abi.encodeWithSelector(Diamond.SelectorNotFound.selector, CounterFacet.increment.selector)
        );
        _expectCutRevert(
            _single(address(0xBEEF), Diamond.FacetCutAction.Replace, _one(CounterFacet.count.selector)),
            abi.encodeWithSelector(Diamond.FacetHasNoCode.selector, address(0xBEEF))
        );
        assertEq(diamond.facetAddress(CounterFacet.count.selector), address(counterFacet));
    }

    function testHiddenRemoveErrors() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _one(CounterFacet.count.selector));

        _expectCutRevert(
            _single(address(counterFacet), Diamond.FacetCutAction.Remove, _one(CounterFacet.count.selector)),
            abi.encodeWithSelector(Diamond.RemoveFacetAddressMustBeZero.selector)
        );
        _expectCutRevert(
            _single(address(0), Diamond.FacetCutAction.Remove, _one(CounterFacet.increment.selector)),
            abi.encodeWithSelector(Diamond.SelectorNotFound.selector, CounterFacet.increment.selector)
        );
        // Built-in functions are not registered, so they cannot be removed.
        _expectCutRevert(
            _single(address(0), Diamond.FacetCutAction.Remove, _one(Diamond.diamondCut.selector)),
            abi.encodeWithSelector(Diamond.SelectorNotFound.selector, Diamond.diamondCut.selector)
        );
        // Removing the same selector twice in one cut fails on the second occurrence.
        bytes4[] memory twice = new bytes4[](2);
        twice[0] = CounterFacet.count.selector;
        twice[1] = CounterFacet.count.selector;
        _expectCutRevert(
            _single(address(0), Diamond.FacetCutAction.Remove, twice),
            abi.encodeWithSelector(Diamond.SelectorNotFound.selector, CounterFacet.count.selector)
        );
        assertEq(diamond.facetAddress(CounterFacet.count.selector), address(counterFacet));
    }

    function testHiddenAddErrors() public {
        _expectCutRevert(
            _single(address(counterFacet), Diamond.FacetCutAction.Add, new bytes4[](0)),
            abi.encodeWithSelector(Diamond.NoSelectors.selector)
        );
        _expectCutRevert(
            _single(address(0), Diamond.FacetCutAction.Add, _counterSelectors()),
            abi.encodeWithSelector(Diamond.FacetHasNoCode.selector, address(0))
        );
        _expectCutRevert(
            _single(alice, Diamond.FacetCutAction.Add, _counterSelectors()),
            abi.encodeWithSelector(Diamond.FacetHasNoCode.selector, alice)
        );
        // Duplicate inside one cut.
        bytes4[] memory twice = new bytes4[](2);
        twice[0] = CounterFacet.count.selector;
        twice[1] = CounterFacet.count.selector;
        _expectCutRevert(
            _single(address(counterFacet), Diamond.FacetCutAction.Add, twice),
            abi.encodeWithSelector(Diamond.SelectorAlreadyExists.selector, CounterFacet.count.selector)
        );
        assertEq(diamond.facetAddresses().length, 0);
    }

    function testHiddenBuiltInSelectorsAreImmutable() public {
        bytes4[7] memory builtIn = [
            Diamond.diamondCut.selector,
            Diamond.facets.selector,
            Diamond.facetFunctionSelectors.selector,
            Diamond.facetAddresses.selector,
            Diamond.facetAddress.selector,
            Diamond.owner.selector,
            Diamond.transferOwnership.selector
        ];
        for (uint256 i = 0; i < builtIn.length; i++) {
            assertEq(diamond.facetAddress(builtIn[i]), address(0));
            _expectCutRevert(
                _single(address(counterFacet), Diamond.FacetCutAction.Add, _one(builtIn[i])),
                abi.encodeWithSelector(Diamond.ImmutableFunction.selector, builtIn[i])
            );
        }
        _expectCutRevert(
            _single(address(counterFacet), Diamond.FacetCutAction.Replace, _one(Diamond.owner.selector)),
            abi.encodeWithSelector(Diamond.ImmutableFunction.selector, Diamond.owner.selector)
        );
        assertEq(diamond.facetAddresses().length, 0);
    }

    function testHiddenBatchCutIsAppliedInOrderAndAtomically() public {
        // One call: add counter, add sequential, replace increment, remove echo.
        Diamond.FacetCut[] memory cuts = new Diamond.FacetCut[](4);
        cuts[0] = Diamond.FacetCut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        cuts[1] = Diamond.FacetCut(address(sequentialFacet), Diamond.FacetCutAction.Add, _sequentialSelectors());
        cuts[2] = Diamond.FacetCut(
            address(counterFacetV2), Diamond.FacetCutAction.Replace, _one(CounterFacet.increment.selector)
        );
        cuts[3] = Diamond.FacetCut(address(0), Diamond.FacetCutAction.Remove, _one(SequentialFacet.echo.selector));
        diamond.diamondCut(cuts, address(0), "");

        assertEq(diamond.facetAddresses().length, 3);
        assertEq(diamond.facetAddress(CounterFacet.increment.selector), address(counterFacetV2));
        assertEq(diamond.facetAddress(SequentialFacet.echo.selector), address(0));
        assertEq(diamond.facetFunctionSelectors(address(sequentialFacet)).length, 3);

        // A batch whose last cut fails leaves no trace of the earlier ones.
        Diamond.FacetCut[] memory bad = new Diamond.FacetCut[](2);
        bad[0] = Diamond.FacetCut(address(0), Diamond.FacetCutAction.Remove, _one(CounterFacet.count.selector));
        bad[1] = Diamond.FacetCut(address(0), Diamond.FacetCutAction.Remove, _one(SequentialFacet.echo.selector));
        _expectCutRevert(bad, abi.encodeWithSelector(Diamond.SelectorNotFound.selector, SequentialFacet.echo.selector));
        assertEq(diamond.facetAddress(CounterFacet.count.selector), address(counterFacet));
        assertEq(CounterFacet(address(diamond)).count(), 0);
    }

    function testHiddenInitialiserRunsInDiamondContext() public {
        diamond.diamondCut(
            _single(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors()),
            address(initializer),
            abi.encodeCall(DiamondInit.init, (500))
        );
        assertEq(CounterFacet(address(diamond)).count(), 500);
        CounterFacet(address(diamond)).increment();
        assertEq(CounterFacet(address(diamond)).count(), 501);

        // Data is ignored when no initialiser is given.
        diamond.diamondCut(
            _single(address(sequentialFacet), Diamond.FacetCutAction.Add, _sequentialSelectors()),
            address(0),
            abi.encodeCall(DiamondInit.fail, ())
        );
        assertEq(diamond.facetAddresses().length, 2);
    }

    function testHiddenInitialiserFailuresRevertTheCut() public {
        Diamond.FacetCut[] memory cuts =
            _single(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());

        vm.expectRevert(DiamondInit.InitRefused.selector);
        diamond.diamondCut(cuts, address(initializer), abi.encodeCall(DiamondInit.fail, ()));

        vm.expectRevert(Diamond.InitFailed.selector);
        diamond.diamondCut(cuts, address(initializer), abi.encodeCall(DiamondInit.failSilently, ()));

        vm.expectRevert(abi.encodeWithSelector(Diamond.InitHasNoCode.selector, alice));
        diamond.diamondCut(cuts, alice, abi.encodeCall(DiamondInit.init, (1)));

        assertEq(diamond.facetAddresses().length, 0);
        assertEq(diamond.facetAddress(CounterFacet.count.selector), address(0));
    }

    function testHiddenRoutingPassesSenderValueAndData() public {
        _cut(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        _cut(address(sequentialFacet), Diamond.FacetCutAction.Add, _sequentialSelectors());

        vm.deal(alice, 3 ether);
        vm.prank(alice);
        CounterFacet(address(diamond)).increment{value: 2 ether}();
        assertEq(CounterFacet(address(diamond)).lastCaller(), alice);
        assertEq(CounterFacet(address(diamond)).received(), 2 ether);
        assertEq(address(diamond).balance, 2 ether);

        bytes memory blob = new bytes(133);
        for (uint256 i = 0; i < blob.length; i++) blob[i] = bytes1(uint8(i * 3 + 1));
        assertEq(keccak256(SequentialFacet(address(diamond)).echo(blob)), keccak256(blob));

        vm.expectRevert(abi.encodeWithSelector(SequentialFacet.Refused.selector, uint256(31)));
        SequentialFacet(address(diamond)).refuse(31);

        // Plain ether transfer is accepted; unknown selectors and short calldata are not.
        vm.prank(alice);
        (bool ok,) = address(diamond).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(diamond).balance, 3 ether);
        (ok,) = address(diamond).call(hex"12345678");
        assertFalse(ok);
        (ok,) = address(diamond).call(hex"01");
        assertFalse(ok);
    }

    function testHiddenOwnershipTransfer() public {
        vm.prank(alice);
        vm.expectRevert(Diamond.NotOwner.selector);
        diamond.transferOwnership(alice);

        vm.expectRevert(Diamond.ZeroAddress.selector);
        diamond.transferOwnership(address(0));

        diamond.transferOwnership(alice);
        assertEq(diamond.owner(), alice);

        Diamond.FacetCut[] memory cuts =
            _single(address(counterFacet), Diamond.FacetCutAction.Add, _counterSelectors());
        vm.expectRevert(Diamond.NotOwner.selector);
        diamond.diamondCut(cuts, address(0), "");

        vm.prank(alice);
        diamond.diamondCut(cuts, address(0), "");
        assertEq(diamond.facetAddresses().length, 1);

        try new Diamond(address(0)) {
            assertTrue(false, "zero owner accepted");
        } catch (bytes memory err) {
            assertEq(bytes4(err), Diamond.ZeroAddress.selector);
        }
    }
}

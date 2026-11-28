// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NamespacedApp.sol";

/// An old-style proxy that keeps its own variables in sequential slots 0, 1 and 2.
contract LegacyProxy {
    address public implementation; // slot 0
    uint256 public legacyCounter; // slot 1
    address public legacyOwner; // slot 2

    constructor(address implementation_, uint256 counter_, address owner_) {
        implementation = implementation_;
        legacyCounter = counter_;
        legacyOwner = owner_;
    }

    function proxyState() external view returns (address, uint256, address) {
        return (implementation, legacyCounter, legacyOwner);
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

contract NamespacedAppHiddenTest is Test {
    NamespacedApp public logic;
    LegacyProxy public proxy;
    NamespacedApp public app; // logic through the proxy
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public legacyOwner = address(0x01D);

    uint256 internal ownableBase;
    uint256 internal counterBase;

    function setUp() public {
        logic = new NamespacedApp();
        proxy = new LegacyProxy(address(logic), 777, legacyOwner);
        app = NamespacedApp(address(proxy));
        ownableBase = uint256(_slot("consinzo.storage.Ownable"));
        counterBase = uint256(_slot("consinzo.storage.Counter"));
    }

    function _slot(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    function _assertProxyStateIntact() internal view {
        (address impl, uint256 counter, address owner_) = proxy.proxyState();
        assertEq(impl, address(logic));
        assertEq(counter, 777);
        assertEq(owner_, legacyOwner);
    }

    function testHiddenKnownLocations() public view {
        assertEq(bytes32(ownableBase), 0xe0730a31143b6cf338774ec851375549b766909386163b0867143dc9306ff100);
        assertEq(bytes32(counterBase), 0x5f8a01231cfda993522d85736cafcc8a28979d38def8a7e59e762ed9fbf5f200);
        assertEq(logic.namespaceSlot("consinzo.storage.Ownable"), bytes32(ownableBase));
        assertEq(logic.namespaceSlot("consinzo.storage.Counter"), bytes32(counterBase));
        assertEq(logic.namespaceSlot(""), _slot(""));
        assertEq(logic.namespaceSlot("a.very.long.namespace.identifier.that.exceeds.thirty.two.bytes"), _slot("a.very.long.namespace.identifier.that.exceeds.thirty.two.bytes"));
        // The last byte of every location is zero.
        assertEq(uint256(logic.namespaceSlot("anything")) & 0xff, 0);
    }

    function testHiddenProxyVariablesSurviveEveryOperation() public {
        app.initialize(address(this));
        _assertProxyStateIntact();
        app.setLimit(10);
        _assertProxyStateIntact();
        vm.prank(alice);
        app.increment();
        vm.prank(bob);
        app.increment();
        _assertProxyStateIntact();
        app.transferOwnership(alice);
        _assertProxyStateIntact();
        vm.prank(alice);
        app.acceptOwnership();
        _assertProxyStateIntact();

        assertEq(app.owner(), alice);
        assertEq(app.total(), 2);
        assertEq(app.limit(), 10);
        // The implementation's own storage was never touched.
        assertEq(logic.owner(), address(0));
        assertEq(logic.total(), 0);
    }

    function testHiddenExactMemberSlots() public {
        app.initialize(address(this));
        app.transferOwnership(bob);
        app.setLimit(55);
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(alice);
            app.increment();
        }
        app.increment();

        assertEq(app.readSlot(bytes32(ownableBase)), bytes32(uint256(uint160(address(this)))));
        assertEq(app.readSlot(bytes32(ownableBase + 1)), bytes32(uint256(uint160(bob))));
        assertEq(app.readSlot(bytes32(counterBase)), bytes32(uint256(4)));
        assertEq(app.readSlot(bytes32(counterBase + 1)), bytes32(uint256(55)));
        assertEq(app.readSlot(keccak256(abi.encode(alice, counterBase + 2))), bytes32(uint256(3)));
        assertEq(app.readSlot(keccak256(abi.encode(address(this), counterBase + 2))), bytes32(uint256(1)));
        assertEq(app.readSlot(keccak256(abi.encode(bob, counterBase + 2))), bytes32(0));
        // The mapping's own base slot stays empty.
        assertEq(app.readSlot(bytes32(counterBase + 2)), bytes32(0));
    }

    function testHiddenDirectInstanceLeavesLowSlotsEmpty() public {
        logic.initialize(alice);
        vm.prank(alice);
        logic.setLimit(3);
        vm.prank(alice);
        logic.transferOwnership(bob);
        logic.increment();
        for (uint256 i = 0; i < 12; i++) {
            assertEq(logic.readSlot(bytes32(i)), bytes32(0));
        }
    }

    function testHiddenInitializeRules() public {
        vm.expectRevert(NamespacedApp.ZeroAddress.selector);
        app.initialize(address(0));
        assertEq(app.owner(), address(0));

        // Before initialisation nobody is the owner.
        vm.expectRevert(NamespacedApp.NotOwner.selector);
        app.setLimit(1);

        vm.prank(alice);
        app.initialize(bob);
        assertEq(app.owner(), bob);

        vm.prank(bob);
        vm.expectRevert(NamespacedApp.AlreadyInitialized.selector);
        app.initialize(alice);
    }

    function testHiddenOwnershipEdgeCases() public {
        app.initialize(address(this));

        // Nothing pending: nobody can accept, not even address(0) semantics by accident.
        vm.prank(alice);
        vm.expectRevert(NamespacedApp.NotPendingOwner.selector);
        app.acceptOwnership();

        vm.prank(alice);
        vm.expectRevert(NamespacedApp.NotOwner.selector);
        app.transferOwnership(alice);

        // Start, then cancel.
        app.transferOwnership(alice);
        app.transferOwnership(address(0));
        assertEq(app.pendingOwner(), address(0));
        vm.prank(alice);
        vm.expectRevert(NamespacedApp.NotPendingOwner.selector);
        app.acceptOwnership();

        // Start, replace, accept by the replacement.
        app.transferOwnership(alice);
        app.transferOwnership(bob);
        vm.prank(alice);
        vm.expectRevert(NamespacedApp.NotPendingOwner.selector);
        app.acceptOwnership();
        vm.prank(bob);
        app.acceptOwnership();
        assertEq(app.owner(), bob);

        // The previous owner lost its rights.
        vm.expectRevert(NamespacedApp.NotOwner.selector);
        app.setLimit(1);
        vm.prank(bob);
        vm.expectRevert(NamespacedApp.NotPendingOwner.selector);
        app.acceptOwnership();
    }

    function testHiddenLimitSemantics() public {
        app.initialize(address(this));
        for (uint256 i = 0; i < 5; i++) app.increment();

        // A limit below the current total blocks further increments.
        app.setLimit(3);
        vm.expectRevert(NamespacedApp.LimitReached.selector);
        app.increment();

        app.setLimit(6);
        assertEq(app.increment(), 6);
        vm.prank(alice);
        vm.expectRevert(NamespacedApp.LimitReached.selector);
        app.increment();
        assertEq(app.countOf(alice), 0);

        // Zero removes the limit.
        app.setLimit(0);
        vm.prank(alice);
        assertEq(app.increment(), 7);
        assertEq(app.countOf(alice), 1);
        assertEq(app.countOf(address(this)), 6);

        vm.prank(alice);
        vm.expectRevert(NamespacedApp.NotOwner.selector);
        app.setLimit(100);
    }
}

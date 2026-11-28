// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NamespacedApp.sol";

contract NamespacedAppTest is Test {
    NamespacedApp public app;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        app = new NamespacedApp();
        app.initialize(address(this));
    }

    function _slot(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    function testNamespaceSlotFormula() public view {
        // Example value published in ERC-7201.
        assertEq(
            app.namespaceSlot("example.main"),
            0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500
        );
        assertEq(app.namespaceSlot("consinzo.storage.Ownable"), _slot("consinzo.storage.Ownable"));
        assertEq(app.namespaceSlot("consinzo.storage.Counter"), _slot("consinzo.storage.Counter"));
    }

    function testOwnerIsStoredInNamespace() public view {
        assertEq(app.owner(), address(this));
        bytes32 base = _slot("consinzo.storage.Ownable");
        assertEq(app.readSlot(base), bytes32(uint256(uint160(address(this)))));
        assertEq(app.readSlot(bytes32(0)), bytes32(0));
    }

    function testCounterIsStoredInNamespace() public {
        vm.prank(alice);
        assertEq(app.increment(), 1);
        vm.prank(alice);
        assertEq(app.increment(), 2);
        vm.prank(bob);
        assertEq(app.increment(), 3);

        assertEq(app.total(), 3);
        assertEq(app.countOf(alice), 2);
        assertEq(app.countOf(bob), 1);

        uint256 base = uint256(_slot("consinzo.storage.Counter"));
        assertEq(app.readSlot(bytes32(base)), bytes32(uint256(3)));
        assertEq(app.readSlot(keccak256(abi.encode(alice, base + 2))), bytes32(uint256(2)));
    }

    function testTwoStepOwnership() public {
        app.transferOwnership(alice);
        assertEq(app.owner(), address(this));
        assertEq(app.pendingOwner(), alice);

        vm.prank(bob);
        vm.expectRevert(NamespacedApp.NotPendingOwner.selector);
        app.acceptOwnership();

        vm.prank(alice);
        app.acceptOwnership();
        assertEq(app.owner(), alice);
        assertEq(app.pendingOwner(), address(0));
    }

    function testLimitBlocksIncrement() public {
        app.setLimit(2);
        app.increment();
        app.increment();
        vm.expectRevert(NamespacedApp.LimitReached.selector);
        app.increment();
        assertEq(app.total(), 2);
    }

    function testInitializeOnlyOnce() public {
        vm.expectRevert(NamespacedApp.AlreadyInitialized.selector);
        app.initialize(alice);
    }
}

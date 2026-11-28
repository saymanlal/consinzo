// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AddressBook.sol";

contract AddressBookHiddenTest is Test {
    AddressBook public book;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        book = new AddressBook();
    }

    function testHiddenInputValidation() public {
        vm.prank(alice);
        vm.expectRevert(AddressBook.ZeroAddress.selector);
        book.setLabel(address(0), "Nobody");

        vm.prank(alice);
        vm.expectRevert(AddressBook.EmptyLabel.selector);
        book.setLabel(bob, "");

        assertEq(book.entryCount(alice), 0);
        assertFalse(book.hasLabel(alice, bob));
    }

    function testHiddenNotFoundCarriesArguments() public {
        vm.expectRevert(abi.encodeWithSelector(AddressBook.EntryNotFound.selector, alice, carol));
        book.getLabel(alice, carol);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AddressBook.EntryNotFound.selector, bob, carol));
        book.removeLabel(carol);
    }

    function testHiddenBooksAreIsolated() public {
        vm.prank(alice);
        book.setLabel(carol, "Carol from work");
        vm.prank(bob);
        book.setLabel(carol, "Aunt Carol");

        assertEq(book.getLabel(alice, carol), "Carol from work");
        assertEq(book.getLabel(bob, carol), "Aunt Carol");

        // Bob removing his entry must not touch Alice's.
        vm.prank(bob);
        book.removeLabel(carol);
        assertFalse(book.hasLabel(bob, carol));
        assertTrue(book.hasLabel(alice, carol));
        assertEq(book.entryCount(alice), 1);
        assertEq(book.entryCount(bob), 0);
    }

    function testHiddenDoubleRemoveReverts() public {
        vm.startPrank(alice);
        book.setLabel(bob, "Bob");
        book.removeLabel(bob);
        vm.expectRevert(abi.encodeWithSelector(AddressBook.EntryNotFound.selector, alice, bob));
        book.removeLabel(bob);
        vm.stopPrank();
        assertEq(book.entryCount(alice), 0);
    }

    function testHiddenReAddAfterRemove() public {
        vm.startPrank(alice);
        book.setLabel(bob, "Bob");
        book.removeLabel(bob);
        vm.stopPrank();

        vm.expectRevert(AddressBook.EntryNotFound.selector);
        book.getLabel(alice, bob);

        vm.prank(alice);
        book.setLabel(bob, "Bob again");
        assertEq(book.getLabel(alice, bob), "Bob again");
        assertEq(book.entryCount(alice), 1);
    }

    function testHiddenCountAcrossManyEntries() public {
        vm.startPrank(alice);
        for (uint160 i = 1; i <= 5; i++) {
            book.setLabel(address(i), "friend");
        }
        book.setLabel(address(3), "best friend");
        book.removeLabel(address(1));
        book.removeLabel(address(5));
        vm.stopPrank();

        assertEq(book.entryCount(alice), 3);
        assertEq(book.getLabel(alice, address(3)), "best friend");
        assertFalse(book.hasLabel(alice, address(1)));
        assertTrue(book.hasLabel(alice, address(2)));
        assertTrue(book.hasLabel(alice, alice) == false);
    }

    function testHiddenLongLabelRoundTrips() public {
        string memory long = "A label longer than thirty-two bytes is stored across several storage slots";
        vm.prank(alice);
        book.setLabel(alice, long);
        assertEq(book.getLabel(alice, alice), long);
    }
}

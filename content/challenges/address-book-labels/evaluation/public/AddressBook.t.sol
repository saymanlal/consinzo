// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AddressBook.sol";

contract AddressBookTest is Test {
    AddressBook public book;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        book = new AddressBook();
    }

    function testSetAndGetLabel() public {
        vm.prank(alice);
        book.setLabel(bob, "Bob");
        assertEq(book.getLabel(alice, bob), "Bob");
        assertTrue(book.hasLabel(alice, bob));
        assertEq(book.entryCount(alice), 1);
    }

    function testOverwriteKeepsCount() public {
        vm.startPrank(alice);
        book.setLabel(bob, "Bob");
        book.setLabel(bob, "Robert");
        vm.stopPrank();
        assertEq(book.getLabel(alice, bob), "Robert");
        assertEq(book.entryCount(alice), 1);
    }

    function testRemoveLabel() public {
        vm.startPrank(alice);
        book.setLabel(bob, "Bob");
        book.setLabel(carol, "Carol");
        book.removeLabel(bob);
        vm.stopPrank();
        assertFalse(book.hasLabel(alice, bob));
        assertTrue(book.hasLabel(alice, carol));
        assertEq(book.entryCount(alice), 1);
    }

    function testGetMissingReverts() public {
        vm.expectRevert(AddressBook.EntryNotFound.selector);
        book.getLabel(alice, bob);
    }
}

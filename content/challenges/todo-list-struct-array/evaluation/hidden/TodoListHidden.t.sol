// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TodoList.sol";

contract TodoListHiddenTest is Test {
    TodoList public todos;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        todos = new TodoList();
    }

    function testHiddenEmptyTextRejected() public {
        vm.prank(alice);
        vm.expectRevert(TodoList.EmptyText.selector);
        todos.add("");
        assertEq(todos.count(alice), 0);
    }

    function testHiddenToggleTwiceRestores() public {
        vm.startPrank(alice);
        todos.add("a");
        assertTrue(todos.toggle(0));
        assertFalse(todos.toggle(0));
        vm.stopPrank();

        (, bool done) = todos.get(alice, 0);
        assertFalse(done);
        assertEq(todos.doneCount(alice), 0);
    }

    function testHiddenDoneCountTracksToggles() public {
        vm.startPrank(alice);
        todos.add("a");
        todos.add("b");
        todos.add("c");
        todos.toggle(0);
        todos.toggle(2);
        vm.stopPrank();
        assertEq(todos.doneCount(alice), 2);
        assertEq(todos.count(alice), 3);

        vm.prank(alice);
        todos.toggle(0);
        assertEq(todos.doneCount(alice), 1);

        (, bool d0) = todos.get(alice, 0);
        (, bool d1) = todos.get(alice, 1);
        (string memory t2, bool d2) = todos.get(alice, 2);
        assertFalse(d0);
        assertFalse(d1);
        assertTrue(d2);
        assertEq(t2, "c");
    }

    function testHiddenOutOfBoundsCarriesIndexAndLength() public {
        vm.startPrank(alice);
        todos.add("a");
        todos.add("b");
        vm.expectRevert(abi.encodeWithSelector(TodoList.IndexOutOfBounds.selector, uint256(2), uint256(2)));
        todos.toggle(2);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(TodoList.IndexOutOfBounds.selector, uint256(9), uint256(2)));
        todos.get(alice, 9);

        vm.expectRevert(abi.encodeWithSelector(TodoList.IndexOutOfBounds.selector, uint256(0), uint256(0)));
        todos.get(bob, 0);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(TodoList.IndexOutOfBounds.selector, uint256(0), uint256(0)));
        todos.toggle(0);
    }

    function testHiddenListsAreIsolated() public {
        vm.prank(alice);
        todos.add("alice item");
        vm.startPrank(bob);
        assertEq(todos.add("bob item"), 0);
        todos.toggle(0);
        vm.stopPrank();

        (string memory aliceText, bool aliceDone) = todos.get(alice, 0);
        (string memory bobText, bool bobDone) = todos.get(bob, 0);
        assertEq(aliceText, "alice item");
        assertFalse(aliceDone);
        assertEq(bobText, "bob item");
        assertTrue(bobDone);
        assertEq(todos.doneCount(alice), 0);
        assertEq(todos.doneCount(bob), 1);
        assertEq(todos.count(alice), 1);
        assertEq(todos.count(bob), 1);
    }

    function testHiddenTextSurvivesToggle() public {
        string memory long = "a todo text that is longer than thirty-two bytes to span several slots";
        vm.startPrank(alice);
        todos.add(long);
        todos.toggle(0);
        vm.stopPrank();
        (string memory text, bool done) = todos.get(alice, 0);
        assertEq(text, long);
        assertTrue(done);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TodoList.sol";

contract TodoListTest is Test {
    TodoList public todos;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        todos = new TodoList();
    }

    function testAddAndGet() public {
        vm.prank(alice);
        uint256 index = todos.add("write tests");
        assertEq(index, 0);
        assertEq(todos.count(alice), 1);

        (string memory text, bool done) = todos.get(alice, 0);
        assertEq(text, "write tests");
        assertFalse(done);
    }

    function testToggle() public {
        vm.startPrank(alice);
        todos.add("write tests");
        bool nowDone = todos.toggle(0);
        vm.stopPrank();

        assertTrue(nowDone);
        (, bool done) = todos.get(alice, 0);
        assertTrue(done);
        assertEq(todos.doneCount(alice), 1);
    }

    function testIndicesIncrease() public {
        vm.startPrank(alice);
        assertEq(todos.add("one"), 0);
        assertEq(todos.add("two"), 1);
        assertEq(todos.add("three"), 2);
        vm.stopPrank();
        assertEq(todos.count(alice), 3);
        (string memory text,) = todos.get(alice, 1);
        assertEq(text, "two");
    }

    function testGetOutOfBoundsReverts() public {
        vm.expectRevert(TodoList.IndexOutOfBounds.selector);
        todos.get(alice, 0);
    }
}

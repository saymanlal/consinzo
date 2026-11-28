// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Whitelist.sol";

contract WhitelistTest is Test {
    Whitelist public list;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        list = new Whitelist();
    }

    function testAddAndRemove() public {
        assertTrue(list.add(alice));
        assertTrue(list.isAllowed(alice));
        assertEq(list.allowedCount(), 1);

        assertTrue(list.remove(alice));
        assertFalse(list.isAllowed(alice));
        assertEq(list.allowedCount(), 0);
    }

    function testBatchAdd() public {
        address[] memory accounts = new address[](3);
        accounts[0] = alice;
        accounts[1] = bob;
        accounts[2] = carol;
        assertEq(list.addBatch(accounts), 3);
        assertEq(list.allowedCount(), 3);
        assertTrue(list.isAllowed(bob));
    }

    function testListedAddressCanCheckIn() public {
        list.add(alice);
        vm.prank(alice);
        list.checkIn();
        vm.prank(alice);
        list.checkIn();
        assertEq(list.checkIns(alice), 2);
    }

    function testUnlistedAddressCannotCheckIn() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotAllowed.selector, bob));
        list.checkIn();
    }

    function testOnlyOwnerAdds() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Whitelist.NotOwner.selector, alice));
        list.add(alice);
    }
}

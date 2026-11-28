// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RevenueSplitter.sol";

contract RevenueSplitterTest is Test {
    RevenueSplitter public splitter;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    function setUp() public {
        address[] memory p = new address[](3);
        uint256[] memory s = new uint256[](3);
        (p[0], p[1], p[2]) = (alice, bob, carol);
        (s[0], s[1], s[2]) = (50, 30, 20);
        splitter = new RevenueSplitter(p, s);
    }

    function _pay(uint256 amount) internal {
        (bool ok, ) = address(splitter).call{value: amount}("");
        assertTrue(ok, "payment failed");
    }

    function testConfiguration() public view {
        assertEq(splitter.payeeCount(), 3);
        assertEq(splitter.payee(0), alice);
        assertEq(splitter.payee(2), carol);
        assertEq(splitter.totalShares(), 100);
        assertEq(splitter.shares(bob), 30);
        assertEq(splitter.totalReceived(), 0);
    }

    function testReleasableIsProportional() public {
        _pay(10 ether);
        assertEq(splitter.totalReceived(), 10 ether);
        assertEq(splitter.releasable(alice), 5 ether);
        assertEq(splitter.releasable(bob), 3 ether);
        assertEq(splitter.releasable(carol), 2 ether);
    }

    function testReleasePaysPayee() public {
        _pay(10 ether);
        vm.prank(bob); // anyone may trigger a release
        uint256 amount = splitter.release(alice);
        assertEq(amount, 5 ether);
        assertEq(alice.balance, 5 ether);
        assertEq(splitter.released(alice), 5 ether);
        assertEq(splitter.totalReleased(), 5 ether);
        assertEq(splitter.releasable(alice), 0);
        assertEq(splitter.releasable(bob), 3 ether);
        assertEq(splitter.totalReceived(), 10 ether);
    }

    function testRevenueAfterRelease() public {
        _pay(10 ether);
        splitter.release(alice);
        _pay(4 ether);
        assertEq(splitter.releasable(alice), 2 ether);
        assertEq(splitter.releasable(bob), 4.2 ether);
        splitter.release(bob);
        splitter.release(alice);
        assertEq(alice.balance, 7 ether);
        assertEq(bob.balance, 4.2 ether);
        assertEq(address(splitter).balance, 2.8 ether);
    }

    function testNonPayeeReverts() public {
        _pay(1 ether);
        vm.expectRevert(RevenueSplitter.NotPayee.selector);
        splitter.release(address(0xDEAD));
    }
}

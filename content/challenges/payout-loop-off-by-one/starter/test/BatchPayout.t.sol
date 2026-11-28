// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BatchPayout.sol";

contract BatchPayoutTest is Test {
    BatchPayout public payout;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        payout = new BatchPayout();
        (bool ok, ) = address(payout).call{value: 10 ether}("");
        require(ok, "funding failed");
    }

    function testQueueTracksTotals() public {
        payout.addPayee(alice, 1 ether);
        payout.addPayee(bob, 2 ether);
        assertEq(payout.payeeCount(), 2);
        assertEq(payout.totalOwed(), 3 ether);
    }

    function testEveryPayeeIsPaid() public {
        payout.addPayee(alice, 1 ether);
        payout.addPayee(bob, 2 ether);
        payout.addPayee(carol, 3 ether);
        payout.payAll();

        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 2 ether);
        assertEq(carol.balance, 3 ether, "last payee must be paid");
        assertEq(address(payout).balance, 4 ether);
    }

    function testSinglePayeeIsPaid() public {
        payout.addPayee(alice, 1 ether);
        payout.payAll();
        assertEq(alice.balance, 1 ether);
    }

    function testQueueIsClearedAfterPayout() public {
        payout.addPayee(alice, 1 ether);
        payout.addPayee(bob, 1 ether);
        payout.payAll();
        assertEq(payout.payeeCount(), 0);
        assertEq(payout.totalOwed(), 0);
    }
}

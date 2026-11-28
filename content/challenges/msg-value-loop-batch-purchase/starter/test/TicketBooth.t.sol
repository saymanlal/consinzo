// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TicketBooth.sol";

contract TicketBoothTest is Test {
    TicketBooth public booth;
    address public alice = address(0xA11CE);
    address public mallory = address(0xBAD);

    function setUp() public {
        booth = new TicketBooth();
        booth.listItem(1, 1 ether, 10); // standard
        booth.listItem(2, 3 ether, 5); // vip
        vm.deal(alice, 20 ether);
        vm.deal(mallory, 20 ether);
    }

    function _ids(uint256 id, uint256 n) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](n);
        for (uint256 i = 0; i < n; i++) ids[i] = id;
    }

    function testSinglePurchase() public {
        vm.prank(alice);
        booth.buy{value: 1 ether}(1);
        assertEq(booth.purchased(alice, 1), 1);
        assertEq(booth.proceeds(), 1 ether);
        assertEq(address(booth).balance, 1 ether);
    }

    function testBatchWithExactTotal() public {
        uint256[] memory ids = _ids(1, 3);
        vm.prank(alice);
        booth.buyBatch{value: 3 ether}(ids);
        assertEq(booth.purchased(alice, 1), 3);
        assertEq(booth.proceeds(), 3 ether);
        assertEq(address(booth).balance, 3 ether);
    }

    function testBatchCannotPayOnceForManyTickets() public {
        uint256[] memory ids = _ids(1, 5);
        vm.expectRevert(TicketBooth.WrongPayment.selector);
        vm.prank(mallory);
        booth.buyBatch{value: 1 ether}(ids);
        assertEq(booth.purchased(mallory, 1), 0);
        assertEq(booth.proceeds(), 0);
        assertEq(mallory.balance, 20 ether);
    }

    function testSingleWrongPaymentReverts() public {
        vm.expectRevert(TicketBooth.WrongPayment.selector);
        vm.prank(alice);
        booth.buy{value: 0.5 ether}(1);
    }
}

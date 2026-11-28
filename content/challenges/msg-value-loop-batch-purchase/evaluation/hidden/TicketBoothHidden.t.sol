// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TicketBooth.sol";

contract TicketBoothHiddenTest is Test {
    TicketBooth public booth;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        booth = new TicketBooth();
        booth.listItem(1, 1 ether, 4);
        booth.listItem(2, 3 ether, 2);
        booth.listItem(3, 0.25 ether, 100);
        vm.deal(alice, 50 ether);
        vm.deal(bob, 50 ether);
    }

    receive() external payable {}

    function _mixed() internal pure returns (uint256[] memory ids) {
        ids = new uint256[](4);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        ids[3] = 1;
    }

    function testHiddenMixedPricesExactTotal() public {
        vm.prank(alice);
        booth.buyBatch{value: 5.25 ether}(_mixed());
        assertEq(booth.purchased(alice, 1), 2);
        assertEq(booth.purchased(alice, 2), 1);
        assertEq(booth.purchased(alice, 3), 1);
        assertEq(booth.proceeds(), 5.25 ether);
        assertEq(address(booth).balance, 5.25 ether);
        (, uint256 stock1) = booth.items(1);
        assertEq(stock1, 2);
    }

    function testHiddenUnderpayByOneWeiReverts() public {
        uint256[] memory ids = _mixed();
        vm.expectRevert(TicketBooth.WrongPayment.selector);
        vm.prank(alice);
        booth.buyBatch{value: 5.25 ether - 1}(ids);
        assertEq(address(booth).balance, 0);
    }

    function testHiddenOverpayReverts() public {
        uint256[] memory ids = _mixed();
        vm.expectRevert(TicketBooth.WrongPayment.selector);
        vm.prank(alice);
        booth.buyBatch{value: 5.25 ether + 1}(ids);

        // Paying the most expensive price once is not enough either.
        vm.expectRevert(TicketBooth.WrongPayment.selector);
        vm.prank(alice);
        booth.buyBatch{value: 3 ether}(ids);
        assertEq(booth.proceeds(), 0);
    }

    function testHiddenSingleItemBatchBehavesLikeBuy() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;
        vm.prank(bob);
        booth.buyBatch{value: 3 ether}(ids);
        assertEq(booth.purchased(bob, 2), 1);

        vm.expectRevert(TicketBooth.WrongPayment.selector);
        vm.prank(bob);
        booth.buyBatch{value: 1 ether}(ids);
    }

    function testHiddenDuplicateIdsRespectStock() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 2;
        ids[1] = 2;
        ids[2] = 2; // only two in stock
        vm.expectRevert(TicketBooth.SoldOut.selector);
        vm.prank(alice);
        booth.buyBatch{value: 9 ether}(ids);
        (, uint256 stock) = booth.items(2);
        assertEq(stock, 2);
        assertEq(alice.balance, 50 ether);
    }

    function testHiddenEmptyAndUnknownItems() public {
        uint256[] memory none = new uint256[](0);
        vm.expectRevert(TicketBooth.EmptyBatch.selector);
        vm.prank(alice);
        booth.buyBatch(none);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 99;
        vm.expectRevert(TicketBooth.UnknownItem.selector);
        vm.prank(alice);
        booth.buyBatch{value: 1 ether}(ids);
    }

    function testHiddenProceedsAlwaysMatchBalanceAndWithdraw() public {
        vm.prank(alice);
        booth.buy{value: 0.25 ether}(3);
        vm.prank(bob);
        booth.buyBatch{value: 5.25 ether}(_mixed());
        uint256[] memory ids = new uint256[](2);
        ids[0] = 3;
        ids[1] = 3;
        vm.prank(alice);
        booth.buyBatch{value: 0.5 ether}(ids);

        assertEq(booth.proceeds(), 6 ether);
        assertEq(address(booth).balance, booth.proceeds());

        uint256 before = address(this).balance;
        booth.withdrawProceeds();
        assertEq(address(this).balance, before + 6 ether);
        assertEq(booth.proceeds(), 0);
        assertEq(address(booth).balance, 0);

        vm.expectRevert(TicketBooth.NotOwner.selector);
        vm.prank(alice);
        booth.withdrawProceeds();
    }
}

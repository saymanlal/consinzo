// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BatchPayout.sol";

contract RefusingPayee {
    receive() external payable {
        revert("NO_THANKS");
    }
}

contract BatchPayoutHiddenTest is Test {
    BatchPayout public payout;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public mallory = address(0xBAD);

    function setUp() public {
        payout = new BatchPayout();
        (bool ok, ) = address(payout).call{value: 20 ether}("");
        require(ok, "funding failed");
    }

    function _payee(uint256 i) internal pure returns (address) {
        return address(uint160(0x100000 + i));
    }

    function testHiddenLargeBatchPaysAllExactly() public {
        uint256 n = 12;
        uint256 total;
        for (uint256 i = 0; i < n; i++) {
            uint256 amount = (i + 1) * 0.1 ether;
            payout.addPayee(_payee(i), amount);
            total += amount;
        }
        assertEq(payout.totalOwed(), total);
        payout.payAll();
        for (uint256 i = 0; i < n; i++) {
            assertEq(_payee(i).balance, (i + 1) * 0.1 ether);
        }
        assertEq(address(payout).balance, 20 ether - total);
    }

    function testHiddenTwoPayeesNeitherSkippedNorDoubled() public {
        payout.addPayee(alice, 1 ether);
        payout.addPayee(bob, 5 ether);
        payout.payAll();
        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 5 ether);
        assertEq(address(payout).balance, 14 ether);
    }

    function testHiddenDuplicateAddressPaidForEachEntry() public {
        payout.addPayee(alice, 1 ether);
        payout.addPayee(bob, 1 ether);
        payout.addPayee(alice, 2 ether);
        payout.payAll();
        assertEq(alice.balance, 3 ether);
        assertEq(bob.balance, 1 ether);
    }

    function testHiddenSecondRoundStartsClean() public {
        payout.addPayee(alice, 1 ether);
        payout.payAll();

        vm.expectRevert(BatchPayout.NoPayees.selector);
        payout.payAll();

        payout.addPayee(bob, 2 ether);
        assertEq(payout.payeeCount(), 1);
        assertEq(payout.totalOwed(), 2 ether);
        payout.payAll();
        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 2 ether);
        assertEq(address(payout).balance, 17 ether);
    }

    function testHiddenInsufficientFundsReverts() public {
        payout.addPayee(alice, 15 ether);
        payout.addPayee(bob, 5 ether + 1);
        vm.expectRevert(BatchPayout.InsufficientFunds.selector);
        payout.payAll();
        assertEq(alice.balance, 0);
        assertEq(payout.payeeCount(), 2);
    }

    function testHiddenFailingLastPayeeRollsBackBatch() public {
        RefusingPayee refuser = new RefusingPayee();
        payout.addPayee(alice, 1 ether);
        payout.addPayee(address(refuser), 1 ether);
        vm.expectRevert(BatchPayout.TransferFailed.selector);
        payout.payAll();
        assertEq(alice.balance, 0);
        assertEq(payout.payeeCount(), 2);
        assertEq(payout.totalOwed(), 2 ether);
        assertEq(address(payout).balance, 20 ether);
    }

    function testHiddenOnlyOwner() public {
        vm.prank(mallory);
        vm.expectRevert(BatchPayout.NotOwner.selector);
        payout.addPayee(mallory, 1 ether);

        payout.addPayee(alice, 1 ether);
        vm.prank(mallory);
        vm.expectRevert(BatchPayout.NotOwner.selector);
        payout.payAll();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FixedSupplyLedger.sol";

contract FixedSupplyLedgerHiddenTest is Test {
    FixedSupplyLedger public ledger;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        ledger = new FixedSupplyLedger("Ledger Token", "LDG", 1000);
    }

    function testHiddenZeroAddressRecipientReverts() public {
        vm.expectRevert(FixedSupplyLedger.ZeroAddress.selector);
        ledger.transfer(address(0), 1);
        assertEq(ledger.balanceOf(address(this)), 1000);
        assertEq(ledger.balanceOf(address(0)), 0);
    }

    function testHiddenInsufficientBalanceBoundary() public {
        ledger.transfer(alice, 10);

        vm.prank(alice);
        vm.expectRevert(FixedSupplyLedger.InsufficientBalance.selector);
        ledger.transfer(bob, 11);

        vm.prank(alice);
        assertTrue(ledger.transfer(bob, 10));
        assertEq(ledger.balanceOf(alice), 0);
        assertEq(ledger.balanceOf(bob), 10);

        vm.prank(alice);
        vm.expectRevert(FixedSupplyLedger.InsufficientBalance.selector);
        ledger.transfer(bob, 1);
    }

    function testHiddenSelfTransferKeepsBalance() public {
        assertTrue(ledger.transfer(address(this), 400));
        assertEq(ledger.balanceOf(address(this)), 1000);
        assertTrue(ledger.transfer(address(this), 1000));
        assertEq(ledger.balanceOf(address(this)), 1000);

        vm.expectRevert(FixedSupplyLedger.InsufficientBalance.selector);
        ledger.transfer(address(this), 1001);
        assertEq(ledger.totalSupply(), 1000);
    }

    function testHiddenZeroAmountTransferSucceeds() public {
        vm.prank(alice);
        assertTrue(ledger.transfer(bob, 0));
        assertEq(ledger.balanceOf(alice), 0);
        assertEq(ledger.balanceOf(bob), 0);
    }

    function testHiddenDeployerIsWhoeverDeploys() public {
        vm.prank(carol);
        FixedSupplyLedger other = new FixedSupplyLedger("Other", "OTH", 77);
        assertEq(other.balanceOf(carol), 77);
        assertEq(other.balanceOf(address(this)), 0);
        assertEq(other.totalSupply(), 77);
        assertEq(other.name(), "Other");
        assertEq(other.symbol(), "OTH");
    }

    function testHiddenZeroSupplyDeployment() public {
        FixedSupplyLedger empty = new FixedSupplyLedger("Empty", "NIL", 0);
        assertEq(empty.totalSupply(), 0);
        assertTrue(empty.transfer(alice, 0));
        vm.expectRevert(FixedSupplyLedger.InsufficientBalance.selector);
        empty.transfer(alice, 1);
    }

    function testHiddenSupplyConservedAcrossChain() public {
        ledger.transfer(alice, 600);
        vm.prank(alice);
        ledger.transfer(bob, 350);
        vm.prank(bob);
        ledger.transfer(carol, 349);
        vm.prank(carol);
        ledger.transfer(address(this), 9);

        assertEq(ledger.balanceOf(address(this)), 409);
        assertEq(ledger.balanceOf(alice), 250);
        assertEq(ledger.balanceOf(bob), 1);
        assertEq(ledger.balanceOf(carol), 340);
        uint256 sum = ledger.balanceOf(address(this)) + ledger.balanceOf(alice) + ledger.balanceOf(bob)
            + ledger.balanceOf(carol);
        assertEq(sum, ledger.totalSupply());
        assertEq(ledger.totalSupply(), 1000);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FixedSupplyLedger.sol";

contract FixedSupplyLedgerTest is Test {
    FixedSupplyLedger public ledger;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        ledger = new FixedSupplyLedger("Ledger Token", "LDG", 1_000_000 ether);
    }

    function testMetadata() public view {
        assertEq(ledger.name(), "Ledger Token");
        assertEq(ledger.symbol(), "LDG");
        assertEq(uint256(ledger.decimals()), 18);
    }

    function testConstructorMintsEverythingToDeployer() public view {
        assertEq(ledger.totalSupply(), 1_000_000 ether);
        assertEq(ledger.balanceOf(address(this)), 1_000_000 ether);
        assertEq(ledger.balanceOf(alice), 0);
    }

    function testTransferMovesBalance() public {
        assertTrue(ledger.transfer(alice, 250 ether));
        assertEq(ledger.balanceOf(alice), 250 ether);
        assertEq(ledger.balanceOf(address(this)), 1_000_000 ether - 250 ether);

        vm.prank(alice);
        assertTrue(ledger.transfer(bob, 100 ether));
        assertEq(ledger.balanceOf(alice), 150 ether);
        assertEq(ledger.balanceOf(bob), 100 ether);
        assertEq(ledger.totalSupply(), 1_000_000 ether);
    }
}

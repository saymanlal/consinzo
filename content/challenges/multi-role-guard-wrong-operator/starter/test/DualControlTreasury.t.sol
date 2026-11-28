// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DualControlTreasury.sol";

contract DualControlTreasuryTest is Test {
    DualControlTreasury public treasury;
    bytes32 internal constant TREASURER = keccak256("TREASURER_ROLE");
    bytes32 internal constant COMPLIANCE = keccak256("COMPLIANCE_ROLE");

    address public officer = address(0x0FF1CE);
    address public treasurerOnly = address(0x7EA5);
    address public complianceOnly = address(0xC0DE);
    address public payee = address(0xBEEF);

    function setUp() public {
        treasury = new DualControlTreasury{value: 10 ether}(1 ether);
        treasury.setRole(TREASURER, officer, true);
        treasury.setRole(COMPLIANCE, officer, true);
        treasury.setRole(TREASURER, treasurerOnly, true);
        treasury.setRole(COMPLIANCE, complianceOnly, true);
    }

    function testOfficerWithBothRolesCanPay() public {
        vm.prank(officer);
        treasury.executePayment(payable(payee), 1 ether);
        assertEq(payee.balance, 1 ether);
        assertEq(address(treasury).balance, 9 ether);
    }

    function testSingleRoleCannotPay() public {
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(treasurerOnly);
        treasury.executePayment(payable(treasurerOnly), 1 ether);
        assertEq(address(treasury).balance, 10 ether);
    }

    function testEitherRoleCanPause() public {
        vm.prank(complianceOnly);
        treasury.pause();
        assertTrue(treasury.paused());
    }

    function testSingleRoleCannotUnpause() public {
        vm.prank(treasurerOnly);
        treasury.pause();
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(treasurerOnly);
        treasury.unpause();
        assertTrue(treasury.paused());

        vm.prank(officer);
        treasury.unpause();
        assertFalse(treasury.paused());
    }
}

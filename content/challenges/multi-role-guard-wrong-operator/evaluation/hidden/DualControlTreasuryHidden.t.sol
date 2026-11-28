// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DualControlTreasury.sol";

contract DualControlTreasuryHiddenTest is Test {
    DualControlTreasury public treasury;
    bytes32 internal constant TREASURER = keccak256("TREASURER_ROLE");
    bytes32 internal constant COMPLIANCE = keccak256("COMPLIANCE_ROLE");

    address public officer = address(0x0FF1CE);
    address public treasurerOnly = address(0x7EA5);
    address public complianceOnly = address(0xC0DE);
    address public stranger = address(0x5712);
    address public payee = address(0xBEEF);

    function setUp() public {
        treasury = new DualControlTreasury{value: 10 ether}(1 ether);
        treasury.setRole(TREASURER, officer, true);
        treasury.setRole(COMPLIANCE, officer, true);
        treasury.setRole(TREASURER, treasurerOnly, true);
        treasury.setRole(COMPLIANCE, complianceOnly, true);
    }

    function testHiddenComplianceOnlyCannotPay() public {
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(complianceOnly);
        treasury.executePayment(payable(complianceOnly), 0.5 ether);
        assertEq(address(treasury).balance, 10 ether);
    }

    function testHiddenOwnerWithoutRolesCannotPay() public {
        // The owner administers roles but is not an officer.
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        treasury.executePayment(payable(payee), 0.5 ether);
    }

    function testHiddenRevokingOneRoleBlocksPayments() public {
        vm.prank(officer);
        treasury.executePayment(payable(payee), 0.25 ether);

        treasury.setRole(COMPLIANCE, officer, false);
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(officer);
        treasury.executePayment(payable(payee), 0.25 ether);
        assertEq(payee.balance, 0.25 ether);
    }

    function testHiddenPauseOpenToEitherRoleOnly() public {
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(stranger);
        treasury.pause();
        assertFalse(treasury.paused());

        vm.prank(treasurerOnly);
        treasury.pause();
        assertTrue(treasury.paused());

        // Payments stop for a fully authorised officer while paused.
        vm.expectRevert(DualControlTreasury.TreasuryPaused.selector);
        vm.prank(officer);
        treasury.executePayment(payable(payee), 0.1 ether);
    }

    function testHiddenUnpauseNeedsBothRoles() public {
        vm.prank(complianceOnly);
        treasury.pause();

        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(complianceOnly);
        treasury.unpause();

        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(stranger);
        treasury.unpause();
        assertTrue(treasury.paused());

        vm.prank(officer);
        treasury.unpause();
        assertFalse(treasury.paused());

        vm.expectRevert(DualControlTreasury.NotPaused.selector);
        vm.prank(officer);
        treasury.unpause();
    }

    function testHiddenPaymentLimitGuard() public {
        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(treasurerOnly);
        treasury.setPaymentLimit(10 ether);

        vm.expectRevert(DualControlTreasury.Unauthorized.selector);
        vm.prank(complianceOnly);
        treasury.setPaymentLimit(10 ether);
        assertEq(treasury.paymentLimit(), 1 ether);

        vm.prank(officer);
        treasury.setPaymentLimit(2 ether);
        assertEq(treasury.paymentLimit(), 2 ether);

        // The owner may set the limit without holding any role.
        treasury.setPaymentLimit(3 ether);
        assertEq(treasury.paymentLimit(), 3 ether);
    }

    function testHiddenSingleRoleCannotRaiseLimitThenDrain() public {
        vm.startPrank(treasurerOnly);
        vm.expectRevert();
        treasury.setPaymentLimit(10 ether);
        vm.expectRevert();
        treasury.executePayment(payable(treasurerOnly), 10 ether);
        vm.stopPrank();
        assertEq(address(treasury).balance, 10 ether);
        assertEq(treasurerOnly.balance, 0);
    }

    function testHiddenLimitAndZeroAddressStillEnforced() public {
        vm.expectRevert(DualControlTreasury.OverLimit.selector);
        vm.prank(officer);
        treasury.executePayment(payable(payee), 1 ether + 1);

        vm.expectRevert(DualControlTreasury.ZeroAddress.selector);
        vm.prank(officer);
        treasury.executePayment(payable(address(0)), 1 ether);

        vm.expectRevert(DualControlTreasury.NotOwner.selector);
        vm.prank(officer);
        treasury.setRole(TREASURER, stranger, true);
    }
}

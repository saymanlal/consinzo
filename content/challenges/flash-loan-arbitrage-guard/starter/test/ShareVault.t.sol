// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ShareVault.sol";

contract ShareVaultTest is Test {
    ShareVault public vault;
    address public attacker = address(0xBAD);
    address public victim = address(0xA11CE);

    function setUp() public {
        vault = new ShareVault();
        vm.deal(attacker, 20 ether);
        vm.deal(victim, 10 ether);
    }

    function testDonationDoesNotStealVictimShares() public {
        vm.prank(attacker);
        vault.deposit{value: 1}();

        // Attacker donates 10 ether directly to the vault
        vm.prank(attacker);
        (bool sent, ) = address(vault).call{value: 10 ether}("");
        assertTrue(sent);

        // Victim deposits 5 ether and must receive fair 1:1 shares (5 ether)
        vm.prank(victim);
        uint256 victimShares = vault.deposit{value: 5 ether}();
        assertEq(victimShares, 5 ether);

        vm.prank(victim);
        uint256 withdrawn = vault.withdraw(victimShares);
        assertEq(withdrawn, 5 ether);
    }
}

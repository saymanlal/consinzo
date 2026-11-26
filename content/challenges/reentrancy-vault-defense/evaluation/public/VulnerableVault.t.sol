// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableVault.sol";

contract ReentrancyAttacker {
    VulnerableVault public vault;
    uint256 public reentries;

    constructor(VulnerableVault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= 1 ether && reentries < 3) {
            reentries++;
            vault.withdraw();
        }
    }
}

contract VulnerableVaultTest is Test {
    VulnerableVault public vault;
    address public alice = address(0xA11CE);

    function setUp() public {
        vault = new VulnerableVault();
        vm.deal(alice, 5 ether);
        vm.prank(alice);
        vault.deposit{value: 5 ether}();
    }

    function testLegitimateWithdrawWorks() public {
        vm.prank(alice);
        vault.withdraw();
        assertEq(alice.balance, 5 ether);
        assertEq(vault.balances(alice), 0);
    }

    function testReentrancyExploitFails() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
        vm.deal(address(this), 1 ether);
        vm.expectRevert();
        attacker.attack{value: 1 ether}();
        assertEq(address(vault).balance, 5 ether);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VulnerableVault.sol";

contract SilentDrainer {
    VulnerableVault public vault;
    constructor(VulnerableVault _v) { vault = _v; }
    function run() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }
    receive() external payable {
        if (address(vault).balance > 0) {
            // Even if inner call catches revert, vault balance must never drop below victim funds
            try vault.withdraw() {} catch {}
        }
    }
}

contract VulnerableVaultHiddenTest is Test {
    VulnerableVault public vault;
    address public victim = address(0xCAFE);

    function setUp() public {
        vault = new VulnerableVault();
        vm.deal(victim, 3 ether);
        vm.prank(victim);
        vault.deposit{value: 3 ether}();
    }

    function testHiddenVictimFundsSafeEvenWithTryCatchReentrancy() public {
        SilentDrainer d = new SilentDrainer(vault);
        d.run{value: 1 ether}();
        assertEq(address(vault).balance, 3 ether);
        assertEq(vault.balances(victim), 3 ether);
    }
}

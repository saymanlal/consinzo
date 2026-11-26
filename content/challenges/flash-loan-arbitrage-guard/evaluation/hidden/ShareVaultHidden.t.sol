// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ShareVault.sol";

contract ShareVaultHiddenTest is Test {
    ShareVault public vault;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        vault = new ShareVault();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testHiddenNormalDepositAndWithdraw() public {
        vm.prank(alice);
        uint256 s = vault.deposit{value: 2 ether}();
        assertEq(s, 2 ether);

        vm.prank(bob);
        uint256 s2 = vault.deposit{value: 3 ether}();
        assertEq(s2, 3 ether);

        vm.prank(alice);
        uint256 out = vault.withdraw(s);
        assertEq(out, 2 ether);
    }
}

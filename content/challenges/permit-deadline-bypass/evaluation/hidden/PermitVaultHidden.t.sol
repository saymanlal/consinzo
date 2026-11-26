// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PermitVault.sol";

contract PermitVaultHiddenTest is Test {
    function testHiddenZeroOwnerRejectedEvenWithZeroSig() public {
        PermitVault v = new PermitVault();
        vm.expectRevert();
        v.permit(address(0), address(0x222), 100, block.timestamp + 100, 27, bytes32(0), bytes32(0));
    }
}
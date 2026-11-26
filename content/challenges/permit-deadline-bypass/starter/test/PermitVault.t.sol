// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/PermitVault.sol";

contract PermitVaultTest is Test {
    function testExpiredDeadlineReverts() public {
        PermitVault v = new PermitVault();
        uint256 dl = block.timestamp + 10;
        vm.warp(dl + 1);
        vm.expectRevert();
        v.permit(address(0x111), address(0x222), 100, dl, 27, bytes32(uint256(1)), bytes32(uint256(2)));
    }
}
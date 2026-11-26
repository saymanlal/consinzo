// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SigGuard.sol";

contract SigGuardHiddenTest is Test {
    function testHiddenZeroAddressSignerRejected() public {
        SigGuard guard = new SigGuard(address(0));
        vm.expectRevert();
        guard.verifyAndConsume(keccak256("msg"), 27, bytes32(0), bytes32(uint256(1)));
    }
}
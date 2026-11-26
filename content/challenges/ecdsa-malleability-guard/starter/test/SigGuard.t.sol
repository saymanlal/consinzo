// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/SigGuard.sol";

contract SigGuardTest is Test {
    uint256 constant HALF_N = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    function testUpperSSignatureRejected() public {
        SigGuard guard = new SigGuard(address(0x1111));
        vm.expectRevert();
        guard.verifyAndConsume(keccak256("msg"), 27, bytes32(uint256(1)), bytes32(HALF_N + 1));
    }

    function testInvalidVRejected() public {
        SigGuard guard = new SigGuard(address(0x1111));
        vm.expectRevert();
        guard.verifyAndConsume(keccak256("msg"), 26, bytes32(uint256(1)), bytes32(uint256(2)));
    }
}
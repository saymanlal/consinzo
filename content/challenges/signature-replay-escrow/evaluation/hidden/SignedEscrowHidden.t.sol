// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SignedEscrow.sol";

contract SignedEscrowHiddenTest is Test {
    SignedEscrow public escrow;
    address public alice = address(0xA11CE);

    function setUp() public {
        escrow = new SignedEscrow{value: 5 ether}(address(0x1111));
    }

    function testHiddenWrongNonceRejected() public {
        vm.expectRevert();
        escrow.claimWithSig(alice, 1 ether, 1, 27, bytes32(uint256(1)), bytes32(uint256(2)));
    }

    function testHiddenZeroSignerCannotBeClaimed() public {
        SignedEscrow zeroSignerEscrow = new SignedEscrow{value: 1 ether}(address(0));
        vm.expectRevert();
        zeroSignerEscrow.claimWithSig(alice, 1 ether, 0, 27, bytes32(0), bytes32(0));
    }
}

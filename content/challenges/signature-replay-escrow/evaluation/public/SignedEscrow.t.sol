// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SignedEscrow.sol";

contract SignedEscrowTest is Test {
    SignedEscrow public escrow;
    address public alice = address(0xA11CE);

    function setUp() public {
        escrow = new SignedEscrow{value: 5 ether}(address(0x1111));
    }

    function testDigestBindsContractAndChainId() public {
        SignedEscrow other = new SignedEscrow{value: 1 ether}(address(0x1111));
        bytes32 d1 = escrow.computeDigest(alice, 1 ether, 0);
        bytes32 d2 = other.computeDigest(alice, 1 ether, 0);
        assertTrue(d1 != d2, "Digest must bind address(this)");
    }

    function testZeroRecoveredAddressRejected() public {
        vm.expectRevert();
        escrow.claimWithSig(alice, 1 ether, 0, 27, bytes32(0), bytes32(0));
    }
}

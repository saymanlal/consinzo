// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/CommitRaffle.sol";

contract CommitRaffleTest is Test {
    function testSameBlockRevealRejected() public {
        CommitRaffle r = new CommitRaffle();
        bytes32 c = keccak256(abi.encodePacked(uint256(42)));
        r.commit(c);
        vm.expectRevert();
        r.reveal(42);
    }

    function testLaterBlockRevealWorks() public {
        CommitRaffle r = new CommitRaffle();
        bytes32 c = keccak256(abi.encodePacked(uint256(42)));
        r.commit(c);
        vm.roll(block.number + 2);
        r.reveal(42);
        assertEq(r.commitments(address(this)), bytes32(0));
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/CommitRaffle.sol";

contract CommitRaffleHiddenTest is Test {
    function testHiddenWrongSecretReverts() public {
        CommitRaffle r = new CommitRaffle();
        r.commit(keccak256(abi.encodePacked(uint256(77))));
        vm.roll(block.number + 2);
        vm.expectRevert();
        r.reveal(78);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/CloneFactory.sol";

contract CloneFactoryHiddenTest is Test {
    function testHiddenZeroImplementationRejected() public {
        CloneFactory f = new CloneFactory();
        vm.expectRevert();
        f.clone(address(0));
    }
}
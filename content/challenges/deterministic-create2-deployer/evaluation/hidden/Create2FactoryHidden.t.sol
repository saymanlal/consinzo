// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/Create2Factory.sol";

contract DummyBoxH { uint256 public y = 1; }

contract Create2FactoryHiddenTest is Test {
    function testHiddenEmptyBytecodeReverts() public {
        Create2Factory f = new Create2Factory();
        vm.expectRevert();
        f.deploy(bytes32(0), "");
    }
}
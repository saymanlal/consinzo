// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/Create2Factory.sol";

contract DummyBox {
    uint256 public x = 77;
}

contract Create2FactoryTest is Test {
    function testPredictedAddressMatchesDeployed() public {
        Create2Factory f = new Create2Factory();
        bytes memory code = type(DummyBox).creationCode;
        bytes32 salt = keccak256("box-1");
        address predicted = f.computeAddress(salt, keccak256(code));
        address deployed = f.deploy(salt, code);
        assertEq(deployed, predicted);
        assertEq(DummyBox(deployed).x(), 77);
    }
}
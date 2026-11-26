// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Create2Factory {
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) public view returns (address) {
        revert("NOT_IMPLEMENTED");
    }

    function deploy(bytes32 salt, bytes memory bytecode) external returns (address addr) {
        revert("NOT_IMPLEMENTED");
    }
}
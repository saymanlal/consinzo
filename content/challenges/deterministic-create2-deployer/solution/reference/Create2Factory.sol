// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Create2Factory {
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) public view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)))));
    }

    function deploy(bytes32 salt, bytes memory bytecode) external returns (address addr) {
        require(bytecode.length > 0, "EMPTY_BYTECODE");
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), "CREATE2_FAILED");
    }
}
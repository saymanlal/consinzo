// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract LogicV1 {
    uint256 public lastNumber;
    function setNumber(uint256 n) external { lastNumber = n; }
}

contract SafeProxy {
    address public implementation; // Slot 0 collides with LogicV1.lastNumber!
    address public owner;

    constructor(address _impl) {
        implementation = _impl;
        owner = msg.sender;
    }

    function setNumber(uint256 n) external {
        (bool ok, ) = implementation.delegatecall(abi.encodeWithSignature("setNumber(uint256)", n));
        require(ok, "DELEGATE_FAILED");
    }
}
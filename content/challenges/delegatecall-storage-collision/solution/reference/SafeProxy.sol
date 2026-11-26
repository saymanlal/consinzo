// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract LogicV1 {
    address public implementation;
    address public owner;
    uint256 public lastNumber;
    function setNumber(uint256 n) external { lastNumber = n; }
}

contract SafeProxy {
    address public implementation;
    address public owner;
    uint256 public lastNumber;

    constructor(address _impl) {
        require(_impl != address(0), "ZERO_IMPL");
        implementation = _impl;
        owner = msg.sender;
    }

    function setNumber(uint256 n) external {
        (bool ok, ) = implementation.delegatecall(abi.encodeWithSignature("setNumber(uint256)", n));
        require(ok, "DELEGATE_FAILED");
    }
}
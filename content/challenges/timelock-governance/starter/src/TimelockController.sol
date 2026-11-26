// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TimelockController {
    uint256 public constant MIN_DELAY = 2 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    address public admin;
    mapping(bytes32 => bool) public queued;

    constructor(address _admin) {
        admin = _admin;
    }

    function getTxHash(address target, uint256 value, bytes calldata data, uint256 eta) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, eta));
    }

    function queue(address target, uint256 value, bytes calldata data, uint256 eta) external returns (bytes32 txHash) {
        revert("NOT_IMPLEMENTED");
    }

    function cancel(bytes32 txHash) external {
        revert("NOT_IMPLEMENTED");
    }

    function execute(address target, uint256 value, bytes calldata data, uint256 eta) external returns (bytes memory) {
        revert("NOT_IMPLEMENTED");
    }
}

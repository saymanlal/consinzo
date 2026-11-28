// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TipJar {
    error NotOwner(address caller);
    error ZeroTip();
    error NothingToWithdraw();
    error TransferFailed();

    event Tipped(address indexed tipper, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    address public owner;
    uint256 public totalTips;
    uint256 public tipperCount;
    mapping(address => uint256) public tipsOf;

    constructor() {
        // TODO: the deployer is the owner
    }

    receive() external payable {
        // TODO: a plain ETH transfer is a tip
        revert("NOT_IMPLEMENTED");
    }

    function tip() external payable {
        // TODO: reject zero value, record the tip, emit Tipped
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external {
        // TODO: owner only; send the whole balance to the owner; emit Withdrawn
        revert("NOT_IMPLEMENTED");
    }
}

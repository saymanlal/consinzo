// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TipJar {
    error NotOwner();
    error ZeroTip();
    error NothingToWithdraw();
    error TransferFailed();

    address public immutable owner;
    uint256 public totalTips;
    mapping(address => uint256) public tipsFrom;

    constructor(address owner_) {
        owner = owner_;
    }

    function tip() external payable {
        _recordTip();
    }

    receive() external payable {
        _recordTip();
    }

    // TODO: VULNERABLE. The whole balance goes to whoever calls this function.
    function withdrawAll() external {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function _recordTip() internal {
        if (msg.value == 0) revert ZeroTip();
        totalTips += msg.value;
        tipsFrom[msg.sender] += msg.value;
    }
}

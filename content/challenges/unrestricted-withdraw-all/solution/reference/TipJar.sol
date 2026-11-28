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

    function withdrawAll() external {
        // Authorisation is the first check: nothing about the jar is revealed or moved
        // for a caller who is not the owner.
        if (msg.sender != owner) revert NotOwner();

        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();

        // Pay the stored owner rather than msg.sender so the destination does not
        // depend on the caller at all.
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function _recordTip() internal {
        if (msg.value == 0) revert ZeroTip();
        totalTips += msg.value;
        tipsFrom[msg.sender] += msg.value;
    }
}

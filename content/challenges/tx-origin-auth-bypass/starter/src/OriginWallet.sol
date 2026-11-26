// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract OriginWallet {
    address public owner;
    constructor() payable { owner = msg.sender; }
    receive() external payable {}

    function transferTo(address payable to, uint256 amount) external {
        require(tx.origin == owner, "NOT_OWNER");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }
}
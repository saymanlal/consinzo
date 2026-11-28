// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TipJar {
    error NotOwner(address caller);
    error ZeroTip();
    error NothingToWithdraw();
    error TransferFailed();

    event Tipped(address indexed tipper, uint256 amount);
    event Withdrawn(address indexed owner, uint256 amount);

    address public immutable owner;
    uint256 public totalTips;
    uint256 public tipperCount;
    mapping(address => uint256) public tipsOf;

    constructor() {
        owner = msg.sender;
    }

    /// @notice Plain ETH transfers (empty calldata) are tips.
    receive() external payable {
        _recordTip();
    }

    function tip() external payable {
        _recordTip();
    }

    function withdraw() external {
        if (msg.sender != owner) revert NotOwner(msg.sender);

        uint256 amount = address(this).balance;
        if (amount == 0) revert NothingToWithdraw();

        // No tip accounting is changed here: the counters are lifetime statistics.
        // `call` forwards all gas so that contract owners (multisigs) can receive.
        (bool ok,) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(owner, amount);
    }

    function _recordTip() internal {
        if (msg.value == 0) revert ZeroTip();

        // First tip from this address: its recorded total is still zero.
        if (tipsOf[msg.sender] == 0) {
            tipperCount += 1;
        }
        tipsOf[msg.sender] += msg.value;
        totalTips += msg.value;

        emit Tipped(msg.sender, msg.value);
    }
}

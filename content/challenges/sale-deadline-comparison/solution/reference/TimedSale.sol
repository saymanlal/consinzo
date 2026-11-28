// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TimedSale {
    error NotOwner();
    error SaleClosed();
    error SaleStillOpen();
    error AlreadyFinalized();
    error ZeroQuantity();
    error WrongPayment();
    error TransferFailed();

    address public immutable owner;
    uint256 public immutable price;
    uint256 public immutable deadline;

    uint256 public totalSold;
    bool public finalized;
    mapping(address => uint256) public purchased;

    constructor(uint256 price_, uint256 duration_) {
        owner = msg.sender;
        price = price_;
        deadline = block.timestamp + duration_;
    }

    /// @dev Single definition of "open" used by both functions, so the two checks can
    ///      never disagree about the boundary. Open is the half-open interval
    ///      [deployment, deadline).
    function _isOpen() internal view returns (bool) {
        return block.timestamp < deadline;
    }

    function buy(uint256 quantity) external payable {
        if (!_isOpen()) revert SaleClosed();
        if (quantity == 0) revert ZeroQuantity();
        if (msg.value != price * quantity) revert WrongPayment();

        purchased[msg.sender] += quantity;
        totalSold += quantity;
    }

    function finalize() external {
        if (msg.sender != owner) revert NotOwner();
        if (_isOpen()) revert SaleStillOpen();
        if (finalized) revert AlreadyFinalized();

        finalized = true;
        (bool ok, ) = owner.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }
}

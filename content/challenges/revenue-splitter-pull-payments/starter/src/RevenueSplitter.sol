// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RevenueSplitter {
    error InvalidPayees();
    error ZeroAddress();
    error ZeroShares();
    error DuplicatePayee();
    error NotPayee();
    error NothingDue();
    error TransferFailed();

    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentReleased(address indexed to, uint256 amount);

    uint256 public totalShares;
    uint256 public totalReleased;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    address[] internal payees;

    constructor(address[] memory payees_, uint256[] memory shares_) payable {
        // TODO: Validate the arrays (InvalidPayees, ZeroAddress, ZeroShares, DuplicatePayee),
        //       store payees and shares, and compute totalShares.
        revert("NOT_IMPLEMENTED");
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function payeeCount() external view returns (uint256) {
        return payees.length;
    }

    function payee(uint256 index) external view returns (address) {
        return payees[index];
    }

    function totalReceived() public view returns (uint256) {
        // TODO: Everything ever received: current balance plus everything already released.
        revert("NOT_IMPLEMENTED");
    }

    function releasable(address account) public view returns (uint256) {
        // TODO: Cumulative entitlement of `account` minus what it has already been paid.
        revert("NOT_IMPLEMENTED");
    }

    function release(address account) external returns (uint256 amount) {
        // TODO: Revert NotPayee / NothingDue, update released and totalReleased,
        //       send the ETH (TransferFailed on failure), emit PaymentReleased.
        revert("NOT_IMPLEMENTED");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract PaymentStreams {
    error InvalidRecipient();
    error ZeroAmount();
    error InvalidTimes();
    error StreamNotActive();
    error NotAuthorized();
    error InsufficientWithdrawable();
    error TransferFailed();

    event StreamCreated(
        uint256 indexed streamId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 deposit,
        uint256 startTime,
        uint256 stopTime
    );
    event Withdrawn(uint256 indexed streamId, address indexed recipient, uint256 amount);
    event StreamCancelled(uint256 indexed streamId, uint256 recipientAmount, uint256 senderAmount);

    struct Stream {
        address sender;
        address recipient;
        address token;
        uint256 deposit;
        uint256 startTime;
        uint256 stopTime;
        uint256 withdrawn;
        bool active;
    }

    uint256 public nextStreamId;
    mapping(uint256 => Stream) public streams;

    function createStream(address recipient, address token, uint256 deposit, uint256 startTime, uint256 stopTime)
        external
        returns (uint256 streamId)
    {
        // TODO: Checks in order: InvalidRecipient, ZeroAmount, InvalidTimes. Store the stream under
        //       the next id, pull the deposit, emit StreamCreated.
        revert("NOT_IMPLEMENTED");
    }

    function streamedAmount(uint256 streamId) public view returns (uint256) {
        // TODO: Total amount unlocked so far for an active stream (README rule 2).
        revert("NOT_IMPLEMENTED");
    }

    function withdrawable(uint256 streamId) public view returns (uint256) {
        // TODO: streamedAmount minus what the recipient already withdrew.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 streamId, uint256 amount) external {
        // TODO: Recipient only. Validate against withdrawable, record, close the stream when the
        //       whole deposit has been withdrawn, transfer, emit Withdrawn.
        revert("NOT_IMPLEMENTED");
    }

    function cancel(uint256 streamId) external returns (uint256 recipientAmount, uint256 senderAmount) {
        // TODO: Sender or recipient only. Close the stream, pay the accrued remainder to the
        //       recipient and refund the unstreamed part to the sender, emit StreamCancelled.
        revert("NOT_IMPLEMENTED");
    }
}

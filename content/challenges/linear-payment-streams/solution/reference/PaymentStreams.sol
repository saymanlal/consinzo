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
        if (recipient == address(0) || recipient == address(this) || recipient == msg.sender) {
            revert InvalidRecipient();
        }
        if (deposit == 0) revert ZeroAmount();
        if (startTime < block.timestamp || stopTime <= startTime) revert InvalidTimes();

        streamId = nextStreamId++;
        streams[streamId] = Stream({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            deposit: deposit,
            startTime: startTime,
            stopTime: stopTime,
            withdrawn: 0,
            active: true
        });

        if (!IERC20(token).transferFrom(msg.sender, address(this), deposit)) revert TransferFailed();
        emit StreamCreated(streamId, msg.sender, recipient, token, deposit, startTime, stopTime);
    }

    function _streamed(Stream storage s) private view returns (uint256) {
        if (block.timestamp <= s.startTime) return 0;
        if (block.timestamp >= s.stopTime) return s.deposit;
        return (s.deposit * (block.timestamp - s.startTime)) / (s.stopTime - s.startTime);
    }

    function _active(uint256 streamId) private view returns (Stream storage s) {
        s = streams[streamId];
        if (!s.active) revert StreamNotActive();
    }

    function _send(address token, address to, uint256 amount) private {
        if (amount == 0) return;
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
    }

    function streamedAmount(uint256 streamId) public view returns (uint256) {
        return _streamed(_active(streamId));
    }

    function withdrawable(uint256 streamId) public view returns (uint256) {
        Stream storage s = _active(streamId);
        return _streamed(s) - s.withdrawn;
    }

    function withdraw(uint256 streamId, uint256 amount) external {
        Stream storage s = _active(streamId);
        if (msg.sender != s.recipient) revert NotAuthorized();
        if (amount == 0) revert ZeroAmount();
        if (amount > _streamed(s) - s.withdrawn) revert InsufficientWithdrawable();

        s.withdrawn += amount;
        if (s.withdrawn == s.deposit) s.active = false;

        _send(s.token, s.recipient, amount);
        emit Withdrawn(streamId, s.recipient, amount);
    }

    function cancel(uint256 streamId) external returns (uint256 recipientAmount, uint256 senderAmount) {
        Stream storage s = _active(streamId);
        if (msg.sender != s.sender && msg.sender != s.recipient) revert NotAuthorized();

        uint256 streamed = _streamed(s);
        recipientAmount = streamed - s.withdrawn;
        // Derived from the same `streamed` value, so the three parts always sum to the deposit.
        senderAmount = s.deposit - streamed;
        s.active = false;

        _send(s.token, s.recipient, recipientAmount);
        _send(s.token, s.sender, senderAmount);
        emit StreamCancelled(streamId, recipientAmount, senderAmount);
    }
}

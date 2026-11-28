// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract HashedTimelock {
    enum State {
        None,
        Open,
        Claimed,
        Refunded
    }

    struct Swap {
        address sender;
        address recipient;
        address token; // address(0) for ETH
        uint256 amount;
        bytes32 hashlock;
        uint64 timelock;
        State state;
    }

    mapping(bytes32 => Swap) public swaps;
    mapping(bytes32 => bytes32) public preimageOf;

    event Locked(
        bytes32 indexed swapId,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint64 timelock
    );
    event Claimed(bytes32 indexed swapId, bytes32 preimage);
    event Refunded(bytes32 indexed swapId);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidTimelock();
    error SwapExists();
    error SwapNotOpen();
    error Expired();
    error NotExpired();
    error InvalidPreimage();
    error TransferFailed();

    function computeSwapId(
        address sender,
        address recipient,
        address token,
        uint256 amount,
        bytes32 hashlock,
        uint64 timelock
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(sender, recipient, token, amount, hashlock, timelock));
    }

    // ------------------------------------------------------------------ lock

    function lockETH(address recipient, bytes32 hashlock, uint64 timelock)
        external
        payable
        returns (bytes32 swapId)
    {
        if (recipient == address(0)) revert ZeroAddress();
        swapId = _open(recipient, address(0), msg.value, hashlock, timelock);
        emit Locked(swapId, msg.sender, recipient, address(0), msg.value, hashlock, timelock);
    }

    function lockToken(address token, uint256 amount, address recipient, bytes32 hashlock, uint64 timelock)
        external
        returns (bytes32 swapId)
    {
        if (recipient == address(0) || token == address(0)) revert ZeroAddress();
        swapId = _open(recipient, token, amount, hashlock, timelock);

        // Record what actually arrived. For a fee-on-transfer token this is less than
        // `amount`; paying out `amount` later would spend other swaps' tokens.
        uint256 beforeBal = IERC20(token).balanceOf(address(this));
        _callToken(token, abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount));
        uint256 received = IERC20(token).balanceOf(address(this)) - beforeBal;
        if (received == 0) revert TransferFailed();
        swaps[swapId].amount = received;

        emit Locked(swapId, msg.sender, recipient, token, received, hashlock, timelock);
    }

    function _open(address recipient, address token, uint256 amount, bytes32 hashlock, uint64 timelock)
        internal
        returns (bytes32 swapId)
    {
        if (amount == 0) revert ZeroAmount();
        if (timelock <= block.timestamp) revert InvalidTimelock();

        swapId = computeSwapId(msg.sender, recipient, token, amount, hashlock, timelock);
        // Ids are never reused, even after a swap is finished, so a swap id observed on
        // one chain always refers to one specific lock.
        if (swaps[swapId].state != State.None) revert SwapExists();

        swaps[swapId] = Swap({
            sender: msg.sender,
            recipient: recipient,
            token: token,
            amount: amount,
            hashlock: hashlock,
            timelock: timelock,
            state: State.Open
        });
    }

    // ------------------------------------------------------------------ settle

    function claim(bytes32 swapId, bytes32 preimage) external {
        Swap storage s = swaps[swapId];
        if (s.state != State.Open) revert SwapNotOpen();
        // Strictly before the timelock: from `timelock` on, only refund is possible, so
        // there is no instant at which both paths are valid.
        if (block.timestamp >= s.timelock) revert Expired();
        if (sha256(abi.encodePacked(preimage)) != s.hashlock) revert InvalidPreimage();

        s.state = State.Claimed;
        preimageOf[swapId] = preimage;
        emit Claimed(swapId, preimage);

        _pay(s.token, s.recipient, s.amount);
    }

    function refund(bytes32 swapId) external {
        Swap storage s = swaps[swapId];
        if (s.state != State.Open) revert SwapNotOpen();
        if (block.timestamp < s.timelock) revert NotExpired();

        s.state = State.Refunded;
        emit Refunded(swapId);

        _pay(s.token, s.sender, s.amount);
    }

    // ------------------------------------------------------------------ transfers

    function _pay(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            _callToken(token, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        }
    }

    /// @dev Accepts tokens that return true and tokens that return nothing.
    function _callToken(address token, bytes memory data) internal {
        (bool ok, bytes memory ret) = token.call(data);
        if (!ok) revert TransferFailed();
        if (ret.length != 0 && !abi.decode(ret, (bool))) revert TransferFailed();
    }
}

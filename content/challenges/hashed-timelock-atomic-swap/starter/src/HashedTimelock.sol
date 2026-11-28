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
        // TODO: keccak256(abi.encode(sender, recipient, token, amount, hashlock, timelock))
        return bytes32(0);
    }

    function lockETH(address recipient, bytes32 hashlock, uint64 timelock)
        external
        payable
        returns (bytes32 swapId)
    {
        // TODO: validate (ZeroAddress, ZeroAmount, InvalidTimelock, SwapExists)
        // TODO: store an Open swap with token == address(0) and amount == msg.value
        revert("NOT_IMPLEMENTED");
    }

    function lockToken(address token, uint256 amount, address recipient, bytes32 hashlock, uint64 timelock)
        external
        returns (bytes32 swapId)
    {
        // TODO: validate as in lockETH (token must not be zero either)
        // TODO: pull the tokens, tolerate tokens without a return value
        // TODO: store the amount actually received
        revert("NOT_IMPLEMENTED");
    }

    function claim(bytes32 swapId, bytes32 preimage) external {
        // TODO: SwapNotOpen, Expired, InvalidPreimage (sha256)
        // TODO: mark Claimed, publish the preimage, pay the recipient
        revert("NOT_IMPLEMENTED");
    }

    function refund(bytes32 swapId) external {
        // TODO: SwapNotOpen, NotExpired
        // TODO: mark Refunded, pay the sender
        revert("NOT_IMPLEMENTED");
    }
}

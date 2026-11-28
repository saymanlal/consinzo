// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract BridgeDepositBox {
    struct Deposit {
        address depositor;
        address recipient;
        uint256 amount;
    }

    address public immutable owner;
    IERC20 public immutable token;

    mapping(uint256 => bool) public supportedChain;
    mapping(uint256 => uint256) public nextNonce;
    mapping(uint256 => uint256) public lockedFor;
    uint256 public totalLocked;

    mapping(uint256 => mapping(uint256 => Deposit)) public deposits;

    error ZeroAddress();
    error NotOwner();
    error SameChain();
    error UnsupportedChain(uint256 chainId);
    error ZeroAmount();
    error TransferFailed();
    error UnknownDeposit();

    event ChainSupportUpdated(uint256 indexed chainId, bool supported);
    event Deposited(
        uint256 indexed destChainId, uint256 indexed nonce, address indexed depositor, address recipient, uint256 amount
    );

    constructor(address token_) {
        if (token_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        token = IERC20(token_);
    }

    function setChainSupported(uint256 chainId, bool supported) external {
        if (msg.sender != owner) revert NotOwner();
        // A deposit "bridged" to the chain it was made on could never be delivered.
        if (chainId == block.chainid) revert SameChain();
        supportedChain[chainId] = supported;
        emit ChainSupportUpdated(chainId, supported);
    }

    function deposit(uint256 destChainId, address recipient, uint256 amount) external returns (uint256 nonce) {
        if (!supportedChain[destChainId]) revert UnsupportedChain(destChainId);
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // One counter per destination: each remote chain sees a gap-free sequence 0, 1, 2, ...
        nonce = nextNonce[destChainId]++;
        deposits[destChainId][nonce] = Deposit(msg.sender, recipient, amount);
        lockedFor[destChainId] += amount;
        totalLocked += amount;
        emit Deposited(destChainId, nonce, msg.sender, recipient, amount);

        // Records are written before the external call; a failed pull reverts all of them.
        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function depositHash(uint256 destChainId, uint256 nonce) external view returns (bytes32) {
        // Nonces are handed out sequentially, so "used" is simply "below the counter".
        if (nonce >= nextNonce[destChainId]) revert UnknownDeposit();
        Deposit storage d = deposits[destChainId][nonce];
        // Source chain id and box address are part of the preimage so the same deposit data
        // from another box or another chain produces a different identifier.
        return keccak256(
            abi.encode(block.chainid, address(this), destChainId, nonce, d.depositor, d.recipient, d.amount)
        );
    }
}

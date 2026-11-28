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
        // TODO: reject the zero address with ZeroAddress()
        owner = msg.sender;
        token = IERC20(token_);
    }

    function setChainSupported(uint256 chainId, bool supported) external {
        // TODO: owner only; block.chainid can never be a destination (SameChain)
        revert("NOT_IMPLEMENTED");
    }

    function deposit(uint256 destChainId, address recipient, uint256 amount) external returns (uint256 nonce) {
        // TODO: UnsupportedChain, ZeroAddress, ZeroAmount checks in that order
        // TODO: take the next nonce of this destination, store the record, update accounting
        // TODO: pull the tokens and revert with TransferFailed() if transferFrom returns false
        revert("NOT_IMPLEMENTED");
    }

    function depositHash(uint256 destChainId, uint256 nonce) external view returns (bytes32) {
        // TODO: UnknownDeposit() for unused nonces
        // TODO: keccak256(abi.encode(block.chainid, address(this), destChainId, nonce, depositor, recipient, amount))
        revert("NOT_IMPLEMENTED");
    }
}

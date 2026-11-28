// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract AttestedBridge {
    uint256 public constant WINDOW = 1 hours;

    address public immutable owner;
    uint256 public threshold;

    address[] internal _relayers;
    mapping(address => bool) public isRelayer;

    mapping(bytes32 => mapping(address => bool)) public hasAttested;
    mapping(bytes32 => bool) public executed;
    mapping(uint256 => mapping(uint256 => bool)) public nonceUsed;

    mapping(address => uint256) public rateLimit;
    // TODO: add the storage you need for the per-token rate-limit window

    error NotOwner();
    error NotRelayer();
    error ZeroAddress();
    error DuplicateRelayer();
    error UnknownRelayer();
    error InvalidThreshold();
    error InvalidTransfer();
    error AlreadyAttested();
    error AlreadyExecuted();
    error NonceAlreadyUsed();
    error InsufficientAttestations(uint256 have, uint256 need);
    error TokenNotSupported();
    error RateLimitExceeded(uint256 requested, uint256 available);
    error TransferFailed();

    event Attested(bytes32 indexed id, address indexed relayer);
    event Executed(bytes32 indexed id, address indexed token, address indexed recipient, uint256 amount);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event ThresholdUpdated(uint256 threshold);
    event RateLimitUpdated(address indexed token, uint256 limitPerWindow);

    constructor(address[] memory relayers_, uint256 threshold_) {
        owner = msg.sender;
        // TODO: register relayers (non-zero, unique) and validate the threshold
    }

    function relayerCount() external view returns (uint256) {
        return _relayers.length;
    }

    function transferId(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount)
        public
        view
        returns (bytes32)
    {
        // TODO: keccak256(abi.encode(srcChainId, block.chainid, address(this), nonce, token, recipient, amount))
        return bytes32(0);
    }

    function attestationCount(bytes32 id) public view returns (uint256 count) {
        // TODO: number of CURRENT relayers that attested to id
        return 0;
    }

    function availableToRelease(address token) public view returns (uint256) {
        // TODO: what execute could release right now for this token
        return 0;
    }

    function attest(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount) external {
        // TODO: NotRelayer, InvalidTransfer, AlreadyExecuted, AlreadyAttested; record the attestation
        revert("NOT_IMPLEMENTED");
    }

    function execute(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount) external {
        // TODO: AlreadyExecuted, NonceAlreadyUsed, InsufficientAttestations, TokenNotSupported, RateLimitExceeded
        // TODO: mark executed + nonce used, charge the window, then transfer (TransferFailed on false)
        revert("NOT_IMPLEMENTED");
    }

    function addRelayer(address relayer) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function removeRelayer(address relayer) external {
        // TODO: must not leave fewer relayers than the threshold
        revert("NOT_IMPLEMENTED");
    }

    function setThreshold(uint256 newThreshold) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }

    function setRateLimit(address token, uint256 limitPerWindow) external {
        // TODO
        revert("NOT_IMPLEMENTED");
    }
}

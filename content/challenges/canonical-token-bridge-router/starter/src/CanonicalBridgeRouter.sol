// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Registry of canonical token mappings plus a lock/release router that keeps
///         separate liquidity and fee books for every (token, destination chain) route.
contract CanonicalBridgeRouter {
    uint256 public constant MAX_FEE_BPS = 1_000; // 10%
    uint256 internal constant BPS = 10_000;

    struct Route {
        bytes32 remoteToken; // zero means "not registered"
        uint16 feeBps;
    }

    address public immutable owner;
    address public relayer;

    mapping(address => mapping(uint256 => Route)) internal _routes;
    /// @notice chainId => remote token id => local token.
    mapping(uint256 => mapping(bytes32 => address)) public localTokenOf;
    /// @notice Net amount locked on a route and still owed to holders on the remote chain.
    mapping(address => mapping(uint256 => uint256)) public lockedLiquidity;
    /// @notice Fees collected on a route and not yet withdrawn.
    mapping(address => mapping(uint256 => uint256)) public accruedFees;
    mapping(uint256 => uint256) public outboundNonce;
    mapping(uint256 => mapping(uint256 => bool)) public inboundProcessed;

    event RouteRegistered(address indexed token, uint256 indexed chainId, bytes32 remoteToken);
    event RouteFeeSet(address indexed token, uint256 indexed chainId, uint256 feeBps);
    event RelayerSet(address indexed relayer);
    event BridgedOut(
        address indexed token,
        uint256 indexed chainId,
        bytes32 remoteToken,
        bytes32 recipient,
        uint256 netAmount,
        uint256 fee,
        uint256 nonce
    );
    event BridgedIn(address indexed token, uint256 indexed chainId, address recipient, uint256 amount, uint256 nonce);
    event FeesWithdrawn(address indexed token, uint256 indexed chainId, address to, uint256 amount);

    error NotOwner();
    error NotRelayer();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidChain();
    error InvalidRemoteToken();
    error RouteExists();
    error RemoteTokenTaken();
    error RouteNotFound();
    error FeeTooHigh();
    error AlreadyProcessed();
    error InsufficientRouteLiquidity();
    error TransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address relayer_) {
        owner = msg.sender;
        relayer = relayer_;
    }

    function setRelayer(address relayer_) external onlyOwner {
        relayer = relayer_;
        emit RelayerSet(relayer_);
    }

    function registerRoute(address token, uint256 chainId, bytes32 remoteToken, uint256 feeBps) external onlyOwner {
        // TODO: validate token, chainId, remoteToken and feeBps (see README for the order)
        // TODO: reject an existing route and a remote token already mapped on that chain
        // TODO: store the route and the reverse lookup, emit RouteRegistered and RouteFeeSet
        revert("NOT_IMPLEMENTED");
    }

    function setRouteFee(address token, uint256 chainId, uint256 feeBps) external onlyOwner {
        // TODO: route must exist, feeBps <= MAX_FEE_BPS, store and emit RouteFeeSet
        revert("NOT_IMPLEMENTED");
    }

    function routeOf(address token, uint256 chainId) external view returns (bytes32 remoteToken, uint256 feeBps) {
        // TODO: return the stored remote token and fee
        revert("NOT_IMPLEMENTED");
    }

    function quote(address token, uint256 chainId, uint256 amount) external view returns (uint256 netAmount, uint256 fee) {
        // TODO: RouteNotFound for unknown routes; fee = amount * feeBps / 10_000 rounded down
        revert("NOT_IMPLEMENTED");
    }

    function bridgeOut(address token, uint256 chainId, uint256 amount, bytes32 recipient)
        external
        returns (uint256 nonce)
    {
        // TODO: validate the route, amount and recipient
        // TODO: pull the tokens and measure what actually arrived
        // TODO: split the received amount into fee and net, book both on this route
        // TODO: increment the per-chain nonce (first nonce is 1) and emit BridgedOut
        revert("NOT_IMPLEMENTED");
    }

    function bridgeIn(uint256 chainId, bytes32 remoteToken, address recipient, uint256 amount, uint256 nonce) external {
        // TODO: only the relayer; resolve the local token through localTokenOf
        // TODO: validate recipient, amount, replay and route liquidity (see README for the order)
        // TODO: mark the nonce, reduce lockedLiquidity, transfer and emit BridgedIn
        revert("NOT_IMPLEMENTED");
    }

    function withdrawFees(address token, uint256 chainId, address to) external onlyOwner returns (uint256 amount) {
        // TODO: send exactly accruedFees[token][chainId] to `to` and zero it; never touch locked liquidity
        revert("NOT_IMPLEMENTED");
    }
}

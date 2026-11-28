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
        if (token == address(0)) revert ZeroAddress();
        if (chainId == 0 || chainId == block.chainid) revert InvalidChain();
        if (remoteToken == bytes32(0)) revert InvalidRemoteToken();
        if (feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        if (_routes[token][chainId].remoteToken != bytes32(0)) revert RouteExists();
        // One remote token must resolve to exactly one local token, otherwise an inbound
        // message would be ambiguous about which locked balance backs it.
        if (localTokenOf[chainId][remoteToken] != address(0)) revert RemoteTokenTaken();

        _routes[token][chainId] = Route({remoteToken: remoteToken, feeBps: uint16(feeBps)});
        localTokenOf[chainId][remoteToken] = token;
        emit RouteRegistered(token, chainId, remoteToken);
        emit RouteFeeSet(token, chainId, feeBps);
    }

    function setRouteFee(address token, uint256 chainId, uint256 feeBps) external onlyOwner {
        Route storage r = _routes[token][chainId];
        if (r.remoteToken == bytes32(0)) revert RouteNotFound();
        if (feeBps > MAX_FEE_BPS) revert FeeTooHigh();
        r.feeBps = uint16(feeBps);
        emit RouteFeeSet(token, chainId, feeBps);
    }

    function routeOf(address token, uint256 chainId) external view returns (bytes32 remoteToken, uint256 feeBps) {
        Route storage r = _routes[token][chainId];
        return (r.remoteToken, r.feeBps);
    }

    function quote(address token, uint256 chainId, uint256 amount) external view returns (uint256 netAmount, uint256 fee) {
        Route storage r = _routes[token][chainId];
        if (r.remoteToken == bytes32(0)) revert RouteNotFound();
        fee = (amount * r.feeBps) / BPS;
        netAmount = amount - fee;
    }

    function bridgeOut(address token, uint256 chainId, uint256 amount, bytes32 recipient)
        external
        returns (uint256 nonce)
    {
        Route storage r = _routes[token][chainId];
        if (r.remoteToken == bytes32(0)) revert RouteNotFound();
        if (amount == 0) revert ZeroAmount();
        if (recipient == bytes32(0)) revert ZeroAddress();

        // Book what actually arrived. A token that charges on transfer would otherwise
        // leave the route owing more than the router holds.
        uint256 beforeBal = IERC20(token).balanceOf(address(this));
        if (!IERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        uint256 received = IERC20(token).balanceOf(address(this)) - beforeBal;
        if (received == 0) revert ZeroAmount();

        uint256 fee = (received * r.feeBps) / BPS; // rounds down, in the user's favour
        uint256 net = received - fee;

        accruedFees[token][chainId] += fee;
        lockedLiquidity[token][chainId] += net;
        nonce = ++outboundNonce[chainId];

        emit BridgedOut(token, chainId, r.remoteToken, recipient, net, fee, nonce);
    }

    function bridgeIn(uint256 chainId, bytes32 remoteToken, address recipient, uint256 amount, uint256 nonce) external {
        if (msg.sender != relayer) revert NotRelayer();
        address token = localTokenOf[chainId][remoteToken];
        if (token == address(0)) revert RouteNotFound();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (inboundProcessed[chainId][nonce]) revert AlreadyProcessed();
        // A route can only release what was locked towards the same chain. Fees and other
        // routes' liquidity are never used to pay an inbound transfer.
        uint256 locked = lockedLiquidity[token][chainId];
        if (amount > locked) revert InsufficientRouteLiquidity();

        inboundProcessed[chainId][nonce] = true;
        unchecked {
            lockedLiquidity[token][chainId] = locked - amount;
        }
        if (!IERC20(token).transfer(recipient, amount)) revert TransferFailed();
        emit BridgedIn(token, chainId, recipient, amount, nonce);
    }

    function withdrawFees(address token, uint256 chainId, address to) external onlyOwner returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        amount = accruedFees[token][chainId];
        if (amount == 0) revert ZeroAmount();
        accruedFees[token][chainId] = 0;
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
        emit FeesWithdrawn(token, chainId, to, amount);
    }
}

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
    mapping(address => uint256) internal _windowStart;
    mapping(address => uint256) internal _spent;

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

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address[] memory relayers_, uint256 threshold_) {
        owner = msg.sender;
        for (uint256 i = 0; i < relayers_.length; i++) {
            _addRelayer(relayers_[i]);
        }
        if (threshold_ == 0 || threshold_ > relayers_.length) revert InvalidThreshold();
        threshold = threshold_;
    }

    // ------------------------------------------------------------------ views

    function relayerCount() external view returns (uint256) {
        return _relayers.length;
    }

    function transferId(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount)
        public
        view
        returns (bytes32)
    {
        // Destination chain id and bridge address bind the attestation to this deployment.
        return keccak256(abi.encode(srcChainId, block.chainid, address(this), nonce, token, recipient, amount));
    }

    /// @notice Attestations from the *current* committee. Counting at read time, instead of
    ///         keeping a running counter, means a removed relayer's vote stops counting
    ///         immediately and nothing has to be cleaned up when the committee changes.
    function attestationCount(bytes32 id) public view returns (uint256 count) {
        uint256 n = _relayers.length;
        for (uint256 i = 0; i < n; i++) {
            if (hasAttested[id][_relayers[i]]) count++;
        }
    }

    function availableToRelease(address token) public view returns (uint256) {
        uint256 limit = rateLimit[token];
        uint256 start = _windowStart[token];
        if (start == 0 || block.timestamp >= start + WINDOW) return limit;
        uint256 spent = _spent[token];
        return spent >= limit ? 0 : limit - spent;
    }

    // -------------------------------------------------------------- transfers

    function attest(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount) external {
        if (!isRelayer[msg.sender]) revert NotRelayer();
        if (token == address(0) || recipient == address(0) || amount == 0) revert InvalidTransfer();
        bytes32 id = transferId(srcChainId, nonce, token, recipient, amount);
        if (executed[id]) revert AlreadyExecuted();
        if (hasAttested[id][msg.sender]) revert AlreadyAttested();
        hasAttested[id][msg.sender] = true;
        emit Attested(id, msg.sender);
    }

    function execute(uint256 srcChainId, uint256 nonce, address token, address recipient, uint256 amount) external {
        bytes32 id = transferId(srcChainId, nonce, token, recipient, amount);
        if (executed[id]) revert AlreadyExecuted();
        // Two different ids can share (srcChainId, nonce) when relayers attest to conflicting
        // contents. The nonce flag guarantees only one of them is ever paid.
        if (nonceUsed[srcChainId][nonce]) revert NonceAlreadyUsed();

        uint256 have = attestationCount(id);
        uint256 need = threshold;
        if (have < need) revert InsufficientAttestations(have, need);

        if (rateLimit[token] == 0) revert TokenNotSupported();
        uint256 available = availableToRelease(token);
        if (amount > available) revert RateLimitExceeded(amount, available);

        // Effects. Everything is final before the token contract gets control.
        executed[id] = true;
        nonceUsed[srcChainId][nonce] = true;
        uint256 start = _windowStart[token];
        if (start == 0 || block.timestamp >= start + WINDOW) {
            _windowStart[token] = block.timestamp;
            _spent[token] = amount;
        } else {
            _spent[token] += amount;
        }
        emit Executed(id, token, recipient, amount);

        if (!IERC20(token).transfer(recipient, amount)) revert TransferFailed();
    }

    // ------------------------------------------------------------------ admin

    function addRelayer(address relayer) external onlyOwner {
        _addRelayer(relayer);
    }

    function removeRelayer(address relayer) external onlyOwner {
        if (!isRelayer[relayer]) revert UnknownRelayer();
        uint256 n = _relayers.length;
        if (n - 1 < threshold) revert InvalidThreshold();
        for (uint256 i = 0; i < n; i++) {
            if (_relayers[i] == relayer) {
                _relayers[i] = _relayers[n - 1];
                _relayers.pop();
                break;
            }
        }
        isRelayer[relayer] = false;
        emit RelayerRemoved(relayer);
    }

    function setThreshold(uint256 newThreshold) external onlyOwner {
        if (newThreshold == 0 || newThreshold > _relayers.length) revert InvalidThreshold();
        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function setRateLimit(address token, uint256 limitPerWindow) external onlyOwner {
        rateLimit[token] = limitPerWindow;
        emit RateLimitUpdated(token, limitPerWindow);
    }

    function _addRelayer(address relayer) internal {
        if (relayer == address(0)) revert ZeroAddress();
        if (isRelayer[relayer]) revert DuplicateRelayer();
        isRelayer[relayer] = true;
        _relayers.push(relayer);
        emit RelayerAdded(relayer);
    }
}

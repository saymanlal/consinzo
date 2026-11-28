// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Destination-side pool of a liquidity-network bridge.
///         LPs deposit one token. A relayer uses the pool to pay bridge users immediately
///         ("fulfil"), keeping a fee. The slow canonical bridge later delivers the full
///         amount ("settle"), which repays the pool and realises the fee.
contract FastBridgePool {
    uint256 internal constant BPS = 10_000;

    enum State {
        None,
        Fulfilled, // paid from the pool, reimbursement pending
        Settled // reimbursement received (or paid directly on the slow path)
    }

    struct Transfer {
        State state;
        bytes32 termsHash; // keccak256(abi.encode(recipient, amount)) recorded at fulfilment
        uint256 fronted; // tokens the pool paid out
    }

    IERC20 public immutable token;
    address public immutable owner;
    address public immutable relayer;
    address public immutable settler;
    uint256 public immutable feeBps;
    uint256 public immutable protocolShareBps;

    /// @notice Tokens the pool can use right now.
    uint256 public idle;
    /// @notice Tokens paid to users and not yet reimbursed, valued at cost.
    uint256 public outstanding;
    /// @notice Fee share that belongs to the protocol, not to LPs.
    uint256 public protocolFees;

    uint256 public totalShares;
    mapping(address => uint256) public sharesOf;
    mapping(bytes32 => Transfer) internal _transfers;

    event Deposited(address indexed lp, uint256 assets, uint256 shares);
    event Withdrawn(address indexed lp, uint256 assets, uint256 shares);
    event Fulfilled(bytes32 indexed transferId, address indexed recipient, uint256 amount, uint256 paid);
    event Settled(bytes32 indexed transferId, uint256 amount, bool wasFulfilled);
    event ProtocolFeesWithdrawn(address indexed to, uint256 amount);

    error InvalidConfig();
    error NotOwner();
    error NotRelayer();
    error NotSettler();
    error ZeroAddress();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares();
    error InsufficientIdleLiquidity();
    error AlreadyHandled();
    error AlreadySettled();
    error TermsMismatch();
    error TransferFailed();

    constructor(address token_, address relayer_, address settler_, uint256 feeBps_, uint256 protocolShareBps_) {
        if (token_ == address(0) || relayer_ == address(0) || settler_ == address(0)) revert InvalidConfig();
        if (feeBps_ > 1_000 || protocolShareBps_ > BPS) revert InvalidConfig();
        token = IERC20(token_);
        owner = msg.sender;
        relayer = relayer_;
        settler = settler_;
        feeBps = feeBps_;
        protocolShareBps = protocolShareBps_;
    }

    // ------------------------------------------------------------------ LP side

    /// @notice Value backing the shares. Built from internal counters, so tokens sent to
    ///         the contract directly cannot move the share price.
    function totalAssets() public view returns (uint256) {
        // TODO: value backing the shares: idle plus outstanding (not the token balance)
        revert("NOT_IMPLEMENTED");
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        // TODO: 1:1 when there are no shares, otherwise pro rata, rounding down
        revert("NOT_IMPLEMENTED");
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        // TODO: 0 when there are no shares, otherwise pro rata, rounding down
        revert("NOT_IMPLEMENTED");
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        // TODO: mint shares at the current price, reject zero assets and zero shares
        // TODO: pull the tokens and add them to idle
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 shares) external returns (uint256 assets) {
        // TODO: burn shares for their pro-rata value, limited by idle liquidity
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------- bridge side

    function quoteFee(uint256 amount) public view returns (uint256) {
        // TODO: amount * feeBps / 10_000, rounded down
        revert("NOT_IMPLEMENTED");
    }

    function transferState(bytes32 transferId) external view returns (State) {
        // TODO: return the state of the transfer
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Pay `recipient` now from pool liquidity; the pool is owed `amount` later.
    function fulfill(bytes32 transferId, address recipient, uint256 amount) external returns (uint256 paid) {
        // TODO: relayer only; validate recipient, amount and that the id is unused
        // TODO: pay amount minus fee from idle and record it as outstanding at cost
        // TODO: remember the terms so that settlement can be matched
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Called by the canonical bridge when the user's funds arrive. Pulls `amount`
    ///         from the settler. Repays the pool if the transfer was fronted, otherwise
    ///         forwards the full amount to the recipient.
    function settle(bytes32 transferId, address recipient, uint256 amount) external {
        // TODO: settler only; validate recipient and amount; reject an id that is already settled
        // TODO: fulfilled: terms must match; pull amount, clear outstanding, split the fee between LPs and protocol
        // TODO: not fulfilled: pull amount and forward all of it to the recipient
        revert("NOT_IMPLEMENTED");
    }

    function withdrawProtocolFees(address to) external returns (uint256 amount) {
        // TODO: owner only; send protocolFees to `to` and zero the counter
        revert("NOT_IMPLEMENTED");
    }

    function _pull(address from, uint256 amount) internal {
        if (!token.transferFrom(from, address(this), amount)) revert TransferFailed();
    }

    function _push(address to, uint256 amount) internal {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }
}

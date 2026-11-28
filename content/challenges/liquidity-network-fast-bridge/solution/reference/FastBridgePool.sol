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
        return idle + outstanding;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalShares;
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalShares;
        return supply == 0 ? 0 : (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets) external returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        shares = convertToShares(assets); // rounds down, in favour of existing LPs
        if (shares == 0) revert ZeroShares();

        idle += assets;
        totalShares += shares;
        sharesOf[msg.sender] += shares;
        _pull(msg.sender, assets);
        emit Deposited(msg.sender, assets, shares);
    }

    function withdraw(uint256 shares) external returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        uint256 held = sharesOf[msg.sender];
        if (shares > held) revert InsufficientShares();
        assets = convertToAssets(shares); // rounds down, in favour of remaining LPs
        // Capital that is out fronting transfers cannot be withdrawn until it is settled.
        if (assets > idle) revert InsufficientIdleLiquidity();

        unchecked {
            sharesOf[msg.sender] = held - shares;
            idle -= assets;
        }
        totalShares -= shares;
        _push(msg.sender, assets);
        emit Withdrawn(msg.sender, assets, shares);
    }

    // ------------------------------------------------------------- bridge side

    function quoteFee(uint256 amount) public view returns (uint256) {
        return (amount * feeBps) / BPS;
    }

    function transferState(bytes32 transferId) external view returns (State) {
        return _transfers[transferId].state;
    }

    /// @notice Pay `recipient` now from pool liquidity; the pool is owed `amount` later.
    function fulfill(bytes32 transferId, address recipient, uint256 amount) external returns (uint256 paid) {
        if (msg.sender != relayer) revert NotRelayer();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        Transfer storage t = _transfers[transferId];
        // Also rejects a transfer the slow path has already paid: fronting it now would
        // pay the user twice and no reimbursement would ever come.
        if (t.state != State.None) revert AlreadyHandled();

        paid = amount - quoteFee(amount);
        if (paid > idle) revert InsufficientIdleLiquidity();

        t.state = State.Fulfilled;
        t.termsHash = keccak256(abi.encode(recipient, amount));
        t.fronted = paid;
        unchecked {
            idle -= paid;
        }
        outstanding += paid; // total assets unchanged: cash became a receivable at cost

        _push(recipient, paid);
        emit Fulfilled(transferId, recipient, amount, paid);
    }

    /// @notice Called by the canonical bridge when the user's funds arrive. Pulls `amount`
    ///         from the settler. Repays the pool if the transfer was fronted, otherwise
    ///         forwards the full amount to the recipient.
    function settle(bytes32 transferId, address recipient, uint256 amount) external {
        if (msg.sender != settler) revert NotSettler();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        Transfer storage t = _transfers[transferId];
        State state = t.state;
        if (state == State.Settled) revert AlreadySettled();

        t.state = State.Settled;
        if (state == State.Fulfilled) {
            // The reimbursement must be for exactly what the relayer fronted against.
            if (t.termsHash != keccak256(abi.encode(recipient, amount))) revert TermsMismatch();
            uint256 fronted = t.fronted;
            uint256 fee = amount - fronted;
            uint256 protocolCut = (fee * protocolShareBps) / BPS;

            outstanding -= fronted;
            idle += amount - protocolCut; // principal back plus the LP part of the fee
            protocolFees += protocolCut;
            _pull(msg.sender, amount);
        } else {
            // Slow path: nobody fronted, so nobody earns a fee.
            _pull(msg.sender, amount);
            _push(recipient, amount);
        }
        emit Settled(transferId, amount, state == State.Fulfilled);
    }

    function withdrawProtocolFees(address to) external returns (uint256 amount) {
        if (msg.sender != owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        amount = protocolFees;
        if (amount == 0) revert ZeroAmount();
        protocolFees = 0;
        _push(to, amount);
        emit ProtocolFeesWithdrawn(to, amount);
    }

    function _pull(address from, uint256 amount) internal {
        if (!token.transferFrom(from, address(this), amount)) revert TransferFailed();
    }

    function _push(address to, uint256 amount) internal {
        if (!token.transfer(to, amount)) revert TransferFailed();
    }
}

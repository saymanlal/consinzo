// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Destination side of an optimistic bridge that pays out ETH.
///         Relayers assert "message (srcChainId, nonce) pays `amount` to `recipient`" and
///         back the assertion with a bond. Anyone may dispute it during the challenge
///         period by matching the bond; an arbiter (standing in for a fraud proof) decides.
contract OptimisticBridge {
    enum Status {
        None,
        Pending,
        Challenged,
        Upheld,
        Finalized
    }

    struct Claim {
        address relayer;
        address recipient;
        uint256 amount;
        uint256 bond; // bond posted by the relayer; a challenger must match it
        uint256 postedAt;
        address challenger;
        Status status;
    }

    address public immutable owner;
    address public immutable arbiter;
    uint256 public immutable challengePeriod;

    /// @notice Bond required for claims posted from now on.
    uint256 public bondAmount;
    /// @notice ETH available to pay finalized messages. Bonds and credits are not part of it.
    uint256 public liquidity;
    /// @notice ETH owed to an address, collected with withdraw().
    mapping(address => uint256) public credits;
    mapping(bytes32 => Claim) internal _claims;

    event LiquidityAdded(address indexed from, uint256 amount);
    event BondAmountSet(uint256 bondAmount);
    event MessagePosted(bytes32 indexed slot, address indexed relayer, address recipient, uint256 amount, uint256 bond);
    event MessageChallenged(bytes32 indexed slot, address indexed challenger);
    event ChallengeResolved(bytes32 indexed slot, bool fraudulent);
    event MessageFinalized(bytes32 indexed slot, address indexed recipient, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    error NotOwner();
    error NotArbiter();
    error InvalidConfig();
    error InvalidMessage();
    error BadBond();
    error SlotTaken();
    error NotPending();
    error NotChallenged();
    error ChallengeWindowClosed();
    error ChallengeWindowOpen();
    error InsufficientLiquidity();
    error NothingToWithdraw();
    error TransferFailed();

    constructor(address arbiter_, uint256 bondAmount_, uint256 challengePeriod_) {
        if (arbiter_ == address(0) || bondAmount_ == 0 || challengePeriod_ == 0) revert InvalidConfig();
        owner = msg.sender;
        arbiter = arbiter_;
        bondAmount = bondAmount_;
        challengePeriod = challengePeriod_;
    }

    receive() external payable {
        liquidity += msg.value;
        emit LiquidityAdded(msg.sender, msg.value);
    }

    function setBondAmount(uint256 bondAmount_) external {
        if (msg.sender != owner) revert NotOwner();
        if (bondAmount_ == 0) revert InvalidConfig();
        bondAmount = bondAmount_;
        emit BondAmountSet(bondAmount_);
    }

    function slotOf(uint256 srcChainId, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encode(srcChainId, nonce));
    }

    function getClaim(bytes32 slot) external view returns (Claim memory) {
        return _claims[slot];
    }

    function postMessage(uint256 srcChainId, uint256 nonce, address recipient, uint256 amount)
        external
        payable
        returns (bytes32 slot)
    {
        if (recipient == address(0) || amount == 0) revert InvalidMessage();
        if (msg.value != bondAmount) revert BadBond();
        slot = slotOf(srcChainId, nonce);
        // A slot is free only if it was never used or its last claim was rejected (rejection
        // deletes the claim). Pending, challenged, upheld and finalized claims all block it.
        if (_claims[slot].status != Status.None) revert SlotTaken();

        _claims[slot] = Claim({
            relayer: msg.sender,
            recipient: recipient,
            amount: amount,
            bond: msg.value,
            postedAt: block.timestamp,
            challenger: address(0),
            status: Status.Pending
        });
        emit MessagePosted(slot, msg.sender, recipient, amount, msg.value);
    }

    function challenge(bytes32 slot) external payable {
        Claim storage c = _claims[slot];
        if (c.status != Status.Pending) revert NotPending();
        if (block.timestamp >= c.postedAt + challengePeriod) revert ChallengeWindowClosed();
        // The challenger matches the bond stored with the claim, not the current global
        // setting, so both sides always risk the same amount.
        if (msg.value != c.bond) revert BadBond();

        c.challenger = msg.sender;
        c.status = Status.Challenged;
        emit MessageChallenged(slot, msg.sender);
    }

    function resolve(bytes32 slot, bool fraudulent) external {
        if (msg.sender != arbiter) revert NotArbiter();
        Claim storage c = _claims[slot];
        if (c.status != Status.Challenged) revert NotChallenged();

        uint256 pot = c.bond * 2;
        if (fraudulent) {
            // Challenger recovers their bond and takes the relayer's. The slot is released
            // so an honest relayer can post the real message.
            address challenger = c.challenger;
            delete _claims[slot];
            credits[challenger] += pot;
        } else {
            // Relayer takes the challenger's bond now; their own bond stays locked until
            // finalization. An upheld claim cannot be challenged again.
            credits[c.relayer] += c.bond;
            c.status = Status.Upheld;
        }
        emit ChallengeResolved(slot, fraudulent);
    }

    function finalize(bytes32 slot) external {
        Claim storage c = _claims[slot];
        if (c.status == Status.Pending) {
            if (block.timestamp < c.postedAt + challengePeriod) revert ChallengeWindowOpen();
        } else if (c.status != Status.Upheld) {
            revert NotPending();
        }
        uint256 amount = c.amount;
        // Payouts come from deposited liquidity only. Using address(this).balance here
        // would spend other relayers' bonds and other users' credits.
        if (amount > liquidity) revert InsufficientLiquidity();

        c.status = Status.Finalized;
        unchecked {
            liquidity -= amount;
        }
        credits[c.recipient] += amount;
        credits[c.relayer] += c.bond;
        emit MessageFinalized(slot, c.recipient, amount);
    }

    function withdraw() external returns (uint256 amount) {
        amount = credits[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        credits[msg.sender] = 0; // effects before interaction
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }
}

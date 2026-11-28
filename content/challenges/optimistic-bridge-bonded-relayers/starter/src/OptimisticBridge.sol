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
        // TODO: count msg.value as liquidity and emit LiquidityAdded
        revert("NOT_IMPLEMENTED");
    }

    function setBondAmount(uint256 bondAmount_) external {
        // TODO: owner only, non-zero, applies to claims posted afterwards
        revert("NOT_IMPLEMENTED");
    }

    function slotOf(uint256 srcChainId, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encode(srcChainId, nonce));
    }

    function getClaim(bytes32 slot) external view returns (Claim memory) {
        // TODO: return the stored claim (all zero when the slot is free)
        revert("NOT_IMPLEMENTED");
    }

    function postMessage(uint256 srcChainId, uint256 nonce, address recipient, uint256 amount)
        external
        payable
        returns (bytes32 slot)
    {
        // TODO: validate the message, the bond and that the slot is free
        // TODO: store a Pending claim that remembers the bond actually posted
        revert("NOT_IMPLEMENTED");
    }

    function challenge(bytes32 slot) external payable {
        // TODO: only Pending claims, only before postedAt + challengePeriod
        // TODO: the challenger must send exactly the bond stored in the claim
        revert("NOT_IMPLEMENTED");
    }

    function resolve(bytes32 slot, bool fraudulent) external {
        // TODO: arbiter only, claim must be Challenged
        // TODO: fraudulent: credit both bonds to the challenger and free the slot
        // TODO: honest: credit the challenger's bond to the relayer and mark the claim Upheld
        revert("NOT_IMPLEMENTED");
    }

    function finalize(bytes32 slot) external {
        // TODO: Pending claims need the challenge period to be over; Upheld claims can finalize at once
        // TODO: pay from `liquidity` only, never from bonds or credits
        // TODO: credit the recipient with the amount and the relayer with their bond
        revert("NOT_IMPLEMENTED");
    }

    function withdraw() external returns (uint256 amount) {
        // TODO: pull payment of credits[msg.sender]; must be safe against reentrancy
        revert("NOT_IMPLEMENTED");
    }
}

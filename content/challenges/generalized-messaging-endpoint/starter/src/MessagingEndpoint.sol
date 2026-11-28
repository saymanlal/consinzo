// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Implemented by applications that receive cross-chain messages.
interface IMessageReceiver {
    function onMessage(uint256 srcChainId, address sender, uint64 nonce, bool ordered, bytes calldata payload)
        external;
}

/// @notice A message in transit. The same struct is emitted on the source chain and
///         presented to the endpoint on the destination chain.
struct Packet {
    uint256 srcChainId;
    address sender;
    uint256 dstChainId;
    address receiver;
    uint64 nonce;
    bool ordered;
    bytes payload;
}

/// @notice One endpoint is deployed per chain. Applications call `send` on their local
///         endpoint; a trusted relayer calls `deliver` on the destination endpoint.
contract MessagingEndpoint {
    enum Status {
        None,
        Delivered,
        Failed,
        Skipped
    }

    struct FeeConfig {
        bool enabled;
        uint120 baseFee;
        uint120 perByteFee;
    }

    /// @notice Gas kept back for the bookkeeping that follows the receiver call.
    uint256 public constant GAS_RESERVE = 60_000;

    uint256 public immutable localChainId;
    address public immutable owner;
    address public immutable relayer;
    /// @notice Gas handed to a receiver for one message.
    uint256 public immutable executionGas;

    mapping(uint256 => FeeConfig) public feeConfig;
    uint256 public collectedFees;

    /// @notice sender => destination chain => receiver => ordered => last nonce used.
    mapping(address => mapping(uint256 => mapping(address => mapping(bool => uint64)))) public outboundNonce;

    mapping(bytes32 => Status) public status;
    /// @notice source chain => sender => receiver => last ordered nonce accepted.
    mapping(uint256 => mapping(address => mapping(address => uint64))) public inboundNonce;
    /// @notice source chain => sender => receiver => id of the failed message blocking the ordered channel.
    mapping(uint256 => mapping(address => mapping(address => bytes32))) public blockedBy;

    uint256 private _executing = 1; // 1 = idle, 2 = inside deliver/retry/skip

    event FeeSet(uint256 indexed dstChainId, uint256 baseFee, uint256 perByteFee);
    event MessageSent(bytes32 indexed id, Packet packet, uint256 fee);
    event MessageDelivered(bytes32 indexed id);
    event MessageFailed(bytes32 indexed id);
    event MessageSkipped(bytes32 indexed id);
    event FeesWithdrawn(address indexed to, uint256 amount);

    error InvalidConfig();
    error NotOwner();
    error NotRelayer();
    error NotReceiver();
    error ZeroAddress();
    error UnsupportedChain();
    error InsufficientFee();
    error RefundFailed();
    error WrongChain();
    error AlreadyDelivered();
    error OutOfOrder();
    error ChannelBlocked();
    error NotFailed();
    error RetryFailed();
    error InsufficientGas();
    error Reentrancy();
    error NothingToWithdraw();
    error TransferFailed();

    modifier nonReentrant() {
        // TODO: revert with Reentrancy() when deliver, retry or skip is entered while one of them is running
        _;
    }

    constructor(uint256 localChainId_, address relayer_, uint256 executionGas_) {
        if (localChainId_ == 0 || relayer_ == address(0) || executionGas_ == 0) revert InvalidConfig();
        localChainId = localChainId_;
        owner = msg.sender;
        relayer = relayer_;
        executionGas = executionGas_;
    }

    // -------------------------------------------------------------------- fees

    function setFee(uint256 dstChainId, uint120 baseFee, uint120 perByteFee) external {
        // TODO: owner only; reject chain id 0 and the local chain; store and enable
        revert("NOT_IMPLEMENTED");
    }

    function quote(uint256 dstChainId, uint256 payloadLength) public view returns (uint256) {
        // TODO: UnsupportedChain() unless enabled; baseFee + perByteFee * payloadLength
        revert("NOT_IMPLEMENTED");
    }

    function withdrawFees(address to) external returns (uint256 amount) {
        // TODO: owner only; send collectedFees to `to` and zero it
        revert("NOT_IMPLEMENTED");
    }

    // -------------------------------------------------------------------- send

    function packetId(Packet memory p) public pure returns (bytes32) {
        // TODO: keccak256(abi.encode(srcChainId, sender, dstChainId, receiver, nonce, ordered, keccak256(payload)))
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Send `payload` to `receiver` on `dstChainId`. Not guarded by the delivery
    ///         lock on purpose: a receiver must be able to reply from inside onMessage.
    function send(uint256 dstChainId, address receiver, bytes calldata payload, bool ordered, address refundTo)
        external
        payable
        returns (bytes32 id, uint64 nonce)
    {
        // TODO: quote the fee, validate receiver and msg.value
        // TODO: take the next nonce of (sender, dstChainId, receiver, ordered), book the fee, emit MessageSent
        // TODO: refund the excess last; RefundFailed() if the refund is rejected
        revert("NOT_IMPLEMENTED");
    }

    // ---------------------------------------------------------------- delivery

    function deliver(Packet calldata p) external nonReentrant {
        // TODO: relayer only, correct chain, not seen before
        // TODO: ordered packets: channel not blocked and nonce is exactly the next one
        // TODO: run the receiver; record Delivered or Failed (and block an ordered channel on failure)
        // TODO: must not be re-enterable
        revert("NOT_IMPLEMENTED");
    }

    /// @notice Re-run a failed message. Anyone may call. Reverts if it fails again.
    function retry(Packet calldata p) external nonReentrant {
        // TODO: only Failed messages; run the receiver again; revert with RetryFailed() if it fails again
        // TODO: success unblocks an ordered channel
        // TODO: must not be re-enterable
        revert("NOT_IMPLEMENTED");
    }

    /// @notice The receiving application gives up on a failed message.
    function skip(Packet calldata p) external nonReentrant {
        // TODO: only the packet's receiver; only Failed messages; mark Skipped and unblock
        revert("NOT_IMPLEMENTED");
    }

    function _execute(Packet calldata p) internal returns (bool ok) {
        // TODO: revert with InsufficientGas() unless the receiver can be given the full executionGas
        // TODO: an address without code counts as a failed delivery
        // TODO: call onMessage with exactly executionGas and return whether it succeeded
        revert("NOT_IMPLEMENTED");
    }
}

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
        if (_executing != 1) revert Reentrancy();
        _executing = 2;
        _;
        _executing = 1;
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
        if (msg.sender != owner) revert NotOwner();
        if (dstChainId == 0 || dstChainId == localChainId) revert InvalidConfig();
        feeConfig[dstChainId] = FeeConfig({enabled: true, baseFee: baseFee, perByteFee: perByteFee});
        emit FeeSet(dstChainId, baseFee, perByteFee);
    }

    function quote(uint256 dstChainId, uint256 payloadLength) public view returns (uint256) {
        FeeConfig memory f = feeConfig[dstChainId];
        if (!f.enabled) revert UnsupportedChain();
        return uint256(f.baseFee) + uint256(f.perByteFee) * payloadLength;
    }

    function withdrawFees(address to) external returns (uint256 amount) {
        if (msg.sender != owner) revert NotOwner();
        if (to == address(0)) revert ZeroAddress();
        amount = collectedFees;
        if (amount == 0) revert NothingToWithdraw();
        collectedFees = 0;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    // -------------------------------------------------------------------- send

    function packetId(Packet memory p) public pure returns (bytes32) {
        return keccak256(
            abi.encode(p.srcChainId, p.sender, p.dstChainId, p.receiver, p.nonce, p.ordered, keccak256(p.payload))
        );
    }

    /// @notice Send `payload` to `receiver` on `dstChainId`. Not guarded by the delivery
    ///         lock on purpose: a receiver must be able to reply from inside onMessage.
    function send(uint256 dstChainId, address receiver, bytes calldata payload, bool ordered, address refundTo)
        external
        payable
        returns (bytes32 id, uint64 nonce)
    {
        uint256 fee = quote(dstChainId, payload.length);
        if (receiver == address(0)) revert ZeroAddress();
        if (msg.value < fee) revert InsufficientFee();

        nonce = ++outboundNonce[msg.sender][dstChainId][receiver][ordered];
        collectedFees += fee;

        Packet memory p = Packet({
            srcChainId: localChainId,
            sender: msg.sender,
            dstChainId: dstChainId,
            receiver: receiver,
            nonce: nonce,
            ordered: ordered,
            payload: payload
        });
        id = packetId(p);
        emit MessageSent(id, p, fee);

        // Refund last. The refund target runs arbitrary code; by now the nonce is taken
        // and the fee is booked, so a nested send() simply gets the next nonce.
        uint256 excess = msg.value - fee;
        if (excess != 0) {
            (bool ok,) = (refundTo == address(0) ? msg.sender : refundTo).call{value: excess}("");
            if (!ok) revert RefundFailed();
        }
    }

    // ---------------------------------------------------------------- delivery

    function deliver(Packet calldata p) external nonReentrant {
        if (msg.sender != relayer) revert NotRelayer();
        if (p.dstChainId != localChainId) revert WrongChain();
        bytes32 id = packetId(p);
        if (status[id] != Status.None) revert AlreadyDelivered();

        if (p.ordered) {
            if (blockedBy[p.srcChainId][p.sender][p.receiver] != bytes32(0)) revert ChannelBlocked();
            if (p.nonce != inboundNonce[p.srcChainId][p.sender][p.receiver] + 1) revert OutOfOrder();
            inboundNonce[p.srcChainId][p.sender][p.receiver] = p.nonce;
        }

        // The message is accounted for before the receiver runs.
        status[id] = Status.Delivered;
        if (_execute(p)) {
            emit MessageDelivered(id);
        } else {
            // A failed delivery is recorded, not reverted: the relayer must not be able
            // to lose a message, and an ordered channel must remember where it stopped.
            status[id] = Status.Failed;
            if (p.ordered) blockedBy[p.srcChainId][p.sender][p.receiver] = id;
            emit MessageFailed(id);
        }
    }

    /// @notice Re-run a failed message. Anyone may call. Reverts if it fails again.
    function retry(Packet calldata p) external nonReentrant {
        bytes32 id = packetId(p);
        if (status[id] != Status.Failed) revert NotFailed();

        status[id] = Status.Delivered;
        if (p.ordered) delete blockedBy[p.srcChainId][p.sender][p.receiver];
        if (!_execute(p)) revert RetryFailed(); // rolls the two writes above back
        emit MessageDelivered(id);
    }

    /// @notice The receiving application gives up on a failed message.
    function skip(Packet calldata p) external nonReentrant {
        if (msg.sender != p.receiver) revert NotReceiver();
        bytes32 id = packetId(p);
        if (status[id] != Status.Failed) revert NotFailed();

        status[id] = Status.Skipped;
        if (p.ordered) delete blockedBy[p.srcChainId][p.sender][p.receiver];
        emit MessageSkipped(id);
    }

    function _execute(Packet calldata p) internal returns (bool ok) {
        // Only 63/64 of the remaining gas can be forwarded. If less than executionGas
        // would reach the receiver, the caller is starving it: refuse instead of
        // recording a failure the receiver did not cause.
        if (gasleft() < (executionGas * 64) / 63 + GAS_RESERVE) revert InsufficientGas();
        // A call to an address without code succeeds and does nothing; that is not a delivery.
        if (p.receiver.code.length == 0) return false;

        bytes memory data =
            abi.encodeCall(IMessageReceiver.onMessage, (p.srcChainId, p.sender, p.nonce, p.ordered, p.payload));
        address target = p.receiver;
        uint256 gasForCall = executionGas;
        // Assembly call so that no return data is copied: a receiver cannot make the
        // endpoint pay for a huge revert payload.
        assembly {
            ok := call(gasForCall, target, 0, add(data, 0x20), mload(data), 0, 0)
        }
    }
}

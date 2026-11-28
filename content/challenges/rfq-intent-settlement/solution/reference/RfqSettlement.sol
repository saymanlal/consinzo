// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}

/// @title RFQ settlement with maker-authorised orders, partial fills and a nonce bitmap.
contract RfqSettlement {
    struct Order {
        address maker;
        address taker; // address(0) means anyone may fill
        address makerToken; // token the maker sells
        address takerToken; // token the maker buys
        uint256 makerAmount;
        uint256 takerAmount;
        uint256 nonce;
        uint256 expiry; // last timestamp at which the order can be filled
    }

    error InvalidOrder();
    error OrderExpired();
    error NotTaker();
    error NotMaker();
    error NonceUsed();
    error ZeroFill();
    error Overfill();
    error NotAuthorised();
    error InvalidSignature();
    error TransferFailed();

    event Filled(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 takerFillAmount,
        uint256 makerFillAmount
    );
    event OrderPreApproved(bytes32 indexed orderHash, address indexed maker);
    event NoncesInvalidated(address indexed maker, uint256 wordPos, uint256 mask);

    bytes32 public constant ORDER_TYPEHASH =
        keccak256(
            "Order(address maker,address taker,address makerToken,address takerToken,uint256 makerAmount,uint256 takerAmount,uint256 nonce,uint256 expiry)"
        );
    bytes4 private constant ERC1271_MAGIC = 0x1626ba7e;
    uint256 private constant SECP256K1_HALF_N =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    bytes32 public immutable DOMAIN_SEPARATOR;

    /// maker => word position => bitmap of used nonces
    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;
    /// order digest => taker amount already filled
    mapping(bytes32 => uint256) public filledTakerAmount;
    /// order digest => approved on-chain by the maker
    mapping(bytes32 => bool) public preApproved;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("ConsinzoRFQ"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    // ---------------------------------------------------------------- views

    function hashOrder(Order calldata order) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                ORDER_TYPEHASH,
                order.maker,
                order.taker,
                order.makerToken,
                order.takerToken,
                order.makerAmount,
                order.takerAmount,
                order.nonce,
                order.expiry
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function isNonceUsed(address maker, uint256 nonce) public view returns (bool) {
        return nonceBitmap[maker][nonce >> 8] & (uint256(1) << (nonce & 0xff)) != 0;
    }

    function remainingTakerAmount(Order calldata order) external view returns (uint256) {
        if (isNonceUsed(order.maker, order.nonce) || block.timestamp > order.expiry) return 0;
        return order.takerAmount - filledTakerAmount[hashOrder(order)];
    }

    // ---------------------------------------------------------------- maker actions

    function preApprove(Order calldata order) external {
        if (msg.sender != order.maker) revert NotMaker();
        bytes32 digest = hashOrder(order);
        preApproved[digest] = true;
        emit OrderPreApproved(digest, msg.sender);
    }

    function invalidateNonce(uint256 nonce) external {
        uint256 mask = uint256(1) << (nonce & 0xff);
        nonceBitmap[msg.sender][nonce >> 8] |= mask;
        emit NoncesInvalidated(msg.sender, nonce >> 8, mask);
    }

    function invalidateNonces(uint256 wordPos, uint256 mask) external {
        nonceBitmap[msg.sender][wordPos] |= mask;
        emit NoncesInvalidated(msg.sender, wordPos, mask);
    }

    // ---------------------------------------------------------------- settlement

    function fill(
        Order calldata order,
        bytes calldata signature,
        uint256 takerFillAmount
    ) external returns (uint256 makerFillAmount) {
        if (order.makerAmount == 0 || order.takerAmount == 0) revert InvalidOrder();
        if (block.timestamp > order.expiry) revert OrderExpired();
        if (order.taker != address(0) && order.taker != msg.sender) revert NotTaker();
        if (isNonceUsed(order.maker, order.nonce)) revert NonceUsed();

        bytes32 digest = hashOrder(order);
        uint256 filled = filledTakerAmount[digest];
        if (takerFillAmount == 0) revert ZeroFill();
        if (takerFillAmount > order.takerAmount - filled) revert Overfill();

        // Rounds down: the maker never gives more than the quoted price.
        makerFillAmount = (takerFillAmount * order.makerAmount) / order.takerAmount;
        if (makerFillAmount == 0) revert ZeroFill();

        _authorise(order.maker, digest, signature);

        // Effects before interactions: a token that re-enters sees the updated fill state.
        filled += takerFillAmount;
        filledTakerAmount[digest] = filled;
        if (filled == order.takerAmount) {
            nonceBitmap[order.maker][order.nonce >> 8] |= uint256(1) << (order.nonce & 0xff);
        }

        _pull(order.takerToken, msg.sender, order.maker, takerFillAmount);
        _pull(order.makerToken, order.maker, msg.sender, makerFillAmount);

        emit Filled(digest, order.maker, msg.sender, takerFillAmount, makerFillAmount);
    }

    // ---------------------------------------------------------------- internals

    function _authorise(address maker, bytes32 digest, bytes calldata signature) internal view {
        if (signature.length == 0) {
            if (!preApproved[digest]) revert NotAuthorised();
            return;
        }
        if (maker.code.length > 0) {
            // Contract makers validate through ERC-1271. Any failure is an invalid signature.
            try IERC1271(maker).isValidSignature(digest, signature) returns (bytes4 magic) {
                if (magic != ERC1271_MAGIC) revert InvalidSignature();
            } catch {
                revert InvalidSignature();
            }
            return;
        }
        if (signature.length != 65) revert InvalidSignature();
        bytes32 r = bytes32(signature[0:32]);
        bytes32 s = bytes32(signature[32:64]);
        uint8 v = uint8(signature[64]);
        // Reject the malleable twin (high s) and non-canonical v values.
        if (uint256(s) > SECP256K1_HALF_N) revert InvalidSignature();
        if (v != 27 && v != 28) revert InvalidSignature();
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0) || recovered != maker) revert InvalidSignature();
    }

    /// @dev transferFrom that accepts tokens returning nothing and rejects a `false` return.
    function _pull(address token, address from, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        if (!ok || (ret.length != 0 && (ret.length < 32 || !abi.decode(ret, (bool))))) {
            revert TransferFailed();
        }
    }
}

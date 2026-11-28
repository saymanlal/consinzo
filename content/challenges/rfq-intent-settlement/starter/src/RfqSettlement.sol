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
        // TODO: build the EIP-712 domain separator for name "ConsinzoRFQ", version "1",
        //       block.chainid and address(this).
        DOMAIN_SEPARATOR = bytes32(0);
    }

    // ---------------------------------------------------------------- views

    function hashOrder(Order calldata order) public view returns (bytes32) {
        // TODO: EIP-712 digest: keccak256("\x19\x01" || DOMAIN_SEPARATOR || hashStruct(order)).
        order;
        return bytes32(0);
    }

    function isNonceUsed(address maker, uint256 nonce) public view returns (bool) {
        // TODO: bit (nonce & 0xff) of nonceBitmap[maker][nonce >> 8].
        maker;
        nonce;
        return false;
    }

    function remainingTakerAmount(Order calldata order) external view returns (uint256) {
        // TODO: 0 if the nonce is used or the order is expired, otherwise takerAmount - filled.
        order;
        return 0;
    }

    // ---------------------------------------------------------------- maker actions

    function preApprove(Order calldata order) external {
        // TODO: only order.maker; mark the order digest as pre-approved and emit OrderPreApproved.
        order;
        revert("NOT_IMPLEMENTED");
    }

    function invalidateNonce(uint256 nonce) external {
        // TODO: set the caller's bit for this nonce and emit NoncesInvalidated.
        nonce;
        revert("NOT_IMPLEMENTED");
    }

    function invalidateNonces(uint256 wordPos, uint256 mask) external {
        // TODO: OR the mask into the caller's bitmap word and emit NoncesInvalidated.
        wordPos;
        mask;
        revert("NOT_IMPLEMENTED");
    }

    // ---------------------------------------------------------------- settlement

    function fill(
        Order calldata order,
        bytes calldata signature,
        uint256 takerFillAmount
    ) external returns (uint256 makerFillAmount) {
        // TODO: 1. validate the order (amounts, expiry, taker, nonce)
        //       2. bound the fill by the remaining amount and compute the maker amount (round down)
        //       3. check the maker's authorisation: pre-approval, ERC-1271 or ECDSA
        //       4. record the fill, burn the nonce when the order is complete
        //       5. move both tokens, rejecting failed transfers
        order;
        signature;
        takerFillAmount;
        makerFillAmount = 0;
        revert("NOT_IMPLEMENTED");
    }
}

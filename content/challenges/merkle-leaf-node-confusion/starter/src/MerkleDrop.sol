// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20Min {
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @notice Token airdrop. Entitlements are committed to by a Merkle root.
/// Trees are built off-chain with `leafHash` for leaves and `hashPair` for nodes.
contract MerkleDrop {
    error NotOwner();
    error InvalidRoot();
    error RootAlreadySet();
    error RootNotSet();
    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();

    event RootSet(bytes32 root);
    event Claimed(uint256 indexed index, address indexed account, uint256 amount);

    address public immutable owner;
    IERC20Min public immutable token;
    bytes32 public merkleRoot;
    mapping(uint256 => bool) public claimed;

    constructor(IERC20Min _token) {
        owner = msg.sender;
        token = _token;
    }

    /// @notice Set the root once, after the distribution has been computed.
    function setRoot(bytes32 root) external {
        if (msg.sender != owner) revert NotOwner();
        if (root == bytes32(0)) revert InvalidRoot();
        if (merkleRoot != bytes32(0)) revert RootAlreadySet();
        merkleRoot = root;
        emit RootSet(root);
    }

    /// @notice Hash of the leaf for entitlement `index`.
    function leafHash(uint256 index, address account, uint96 amount) public pure returns (bytes32) {
        // TODO: this preimage is 32 + 20 + 12 = 64 bytes, hashed once.
        return keccak256(abi.encodePacked(index, account, amount));
    }

    /// @notice Hash of an internal node: the two children in ascending order.
    function hashPair(bytes32 a, bytes32 b) public pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function verify(bytes32[] calldata proof, bytes32 leaf) public view returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computed = hashPair(computed, proof[i]);
        }
        return computed == merkleRoot;
    }

    /// @notice Pay entitlement `index` to `account`. Anyone may submit the claim.
    function claim(uint256 index, address account, uint96 amount, bytes32[] calldata proof) external {
        if (merkleRoot == bytes32(0)) revert RootNotSet();
        if (claimed[index]) revert AlreadyClaimed();
        if (!verify(proof, leafHash(index, account, amount))) revert InvalidProof();

        claimed[index] = true;
        if (!token.transfer(account, amount)) revert TransferFailed();
        emit Claimed(index, account, amount);
    }
}

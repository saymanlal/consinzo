// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

/// @title SafeNFT
/// @notice ERC-721 with safeTransferFrom / safeMint receiver checks.
contract SafeNFT {
    address public immutable minter;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    error NotMinter();
    error ZeroAddress();
    error AlreadyMinted();
    error NonexistentToken();
    error NotAuthorized();
    error WrongOwner();
    error UnsafeRecipient();

    constructor() {
        minter = msg.sender;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert NonexistentToken();
        return owner;
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (_owners[tokenId] == address(0)) revert NonexistentToken();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function approve(address approved, uint256 tokenId) external {
        // TODO: Owner or operator only; store the approval; emit Approval
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        // TODO: Checked transfer with no receiver check
        revert("NOT_IMPLEMENTED");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        // TODO: Transfer, then run the receiver check with empty data
        revert("NOT_IMPLEMENTED");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        // TODO: Transfer, then run the receiver check with `data`
        revert("NOT_IMPLEMENTED");
    }

    function safeMint(address to, uint256 tokenId) external {
        // TODO: Mint, then run the receiver check with from = address(0) and empty data
        revert("NOT_IMPLEMENTED");
    }

    function safeMint(address to, uint256 tokenId, bytes calldata data) external {
        // TODO: Mint, then run the receiver check with from = address(0) and `data`
        revert("NOT_IMPLEMENTED");
    }

    // TODO: Add internal helpers for the transfer, the mint and the receiver check
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @title MinimalNFT
/// @notice Core ERC-721 ownership, single-token approval and transfer logic.
contract MinimalNFT {
    address public immutable minter;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    error NotMinter();
    error ZeroAddress();
    error AlreadyMinted();
    error NonexistentToken();
    error NotAuthorized();
    error WrongOwner();

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

    function mint(address to, uint256 tokenId) external {
        if (msg.sender != minter) revert NotMinter();
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert AlreadyMinted();

        _owners[tokenId] = to;
        unchecked {
            _balances[to] += 1;
        }
        emit Transfer(address(0), to, tokenId);
    }

    function approve(address approved, uint256 tokenId) external {
        address owner = ownerOf(tokenId); // reverts for nonexistent tokens
        if (msg.sender != owner) revert NotAuthorized();
        _tokenApprovals[tokenId] = approved;
        emit Approval(owner, approved, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId); // reverts for nonexistent tokens
        if (from != owner) revert WrongOwner();
        if (to == address(0)) revert ZeroAddress();
        if (msg.sender != owner && msg.sender != _tokenApprovals[tokenId]) revert NotAuthorized();

        // The approval was granted by `from`; it must not survive the change of owner.
        delete _tokenApprovals[tokenId];

        unchecked {
            _balances[from] -= 1; // from owns tokenId, so its balance is at least 1
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
}

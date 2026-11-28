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
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotAuthorized();
        _tokenApprovals[tokenId] = approved;
        emit Approval(owner, approved, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        _transfer(from, to, tokenId);
        _checkReceiver(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        _transfer(from, to, tokenId);
        _checkReceiver(from, to, tokenId, data);
    }

    function safeMint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
        _checkReceiver(address(0), to, tokenId, "");
    }

    function safeMint(address to, uint256 tokenId, bytes calldata data) external {
        _mint(to, tokenId);
        _checkReceiver(address(0), to, tokenId, data);
    }

    function _mint(address to, uint256 tokenId) internal {
        if (msg.sender != minter) revert NotMinter();
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert AlreadyMinted();

        _owners[tokenId] = to;
        unchecked {
            _balances[to] += 1;
        }
        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        address owner = ownerOf(tokenId);
        if (from != owner) revert WrongOwner();
        if (to == address(0)) revert ZeroAddress();
        if (
            msg.sender != owner && msg.sender != _tokenApprovals[tokenId]
                && !isApprovedForAll[owner][msg.sender]
        ) revert NotAuthorized();

        delete _tokenApprovals[tokenId];
        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    /// @dev Must run after all state changes: the recipient may act on the token in the hook.
    function _checkReceiver(address from, address to, uint256 tokenId, bytes memory data) internal {
        if (to.code.length == 0) return; // EOAs (and contracts under construction) are not called

        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 answer) {
            if (answer != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
        } catch {
            // Reverted, or the function does not exist: normalise to one error.
            revert UnsafeRecipient();
        }
    }
}

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
        // TODO: Return the owner; revert with NonexistentToken() if unminted
        revert("NOT_IMPLEMENTED");
    }

    function balanceOf(address owner) external view returns (uint256) {
        // TODO: Return the token count; revert with ZeroAddress() for address(0)
        revert("NOT_IMPLEMENTED");
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        // TODO: Return the approved address; revert with NonexistentToken() if unminted
        revert("NOT_IMPLEMENTED");
    }

    function mint(address to, uint256 tokenId) external {
        // TODO: Minter only; reject address(0) and existing tokens; assign owner; emit Transfer
        revert("NOT_IMPLEMENTED");
    }

    function approve(address approved, uint256 tokenId) external {
        // TODO: Only the current owner may approve; store the approval; emit Approval
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        // TODO: Check existence, `from`, `to` and authorisation; clear approval; move the token; emit Transfer
        revert("NOT_IMPLEMENTED");
    }
}

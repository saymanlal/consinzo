// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ConsinzoNFT {
    string public name;
    string public symbol;
    address public owner;
    uint256 public immutable maxSupply;
    uint256 public totalMinted;

    address public royaltyReceiver;
    uint96 public royaltyBps;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, address _royaltyReceiver, uint96 _royaltyBps) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        maxSupply = _maxSupply;
        royaltyReceiver = _royaltyReceiver;
        royaltyBps = _royaltyBps;
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address o = _owners[tokenId];
        require(o != address(0), "NOT_MINTED");
        return o;
    }

    function balanceOf(address account) public view returns (uint256) {
        require(account != address(0), "ZERO_ADDRESS");
        return _balances[account];
    }

    function mint(address to) external returns (uint256 tokenId) {
        revert("NOT_IMPLEMENTED");
    }

    function approve(address to, uint256 tokenId) external {
        revert("NOT_IMPLEMENTED");
    }

    function setApprovalForAll(address operator, bool approved) external {
        revert("NOT_IMPLEMENTED");
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        revert("NOT_IMPLEMENTED");
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        revert("NOT_IMPLEMENTED");
    }
}

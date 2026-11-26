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

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, address _royaltyReceiver, uint96 _royaltyBps) {
        require(_royaltyBps <= 1000, "ROYALTY_TOO_HIGH");
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
        require(msg.sender == owner, "ONLY_OWNER");
        require(to != address(0), "ZERO_ADDRESS");
        require(totalMinted < maxSupply, "MAX_SUPPLY");
        totalMinted += 1;
        tokenId = totalMinted;
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function approve(address to, uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        require(msg.sender == tokenOwner || isApprovedForAll[tokenOwner][msg.sender], "NOT_AUTHORIZED");
        getApproved[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner == from, "WRONG_FROM");
        require(to != address(0), "ZERO_ADDRESS");
        require(
            msg.sender == tokenOwner ||
                getApproved[tokenId] == msg.sender ||
                isApprovedForAll[tokenOwner][msg.sender],
            "NOT_AUTHORIZED"
        );
        delete getApproved[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        ownerOf(tokenId);
        return (royaltyReceiver, (salePrice * royaltyBps) / 10_000);
    }
}

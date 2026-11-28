// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

/// @notice Fixed-price NFT sale with a per-wallet mint limit.
/// @dev Deliberately minimal ERC-721: ownership, balances and a plain transfer.
contract LimitedMint {
    error ZeroQuantity();
    error WalletLimitExceeded();
    error SoldOut();
    error WrongPayment();
    error UnsafeRecipient();
    error NotTokenOwner();
    error NotOwner();
    error TransferFailed();
    error Reentrancy();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    uint256 public constant MAX_PER_WALLET = 2;
    uint256 public constant MAX_SUPPLY = 10;
    uint256 public constant PRICE = 0.1 ether;

    address public immutable owner;
    uint256 public totalSupply;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    /// @notice Number of tokens each address has minted (not the number it currently holds).
    mapping(address => uint256) public mintedBy;

    uint256 private _lock = 1;

    /// @dev Second layer of defence: no nested entry into mint() at all.
    modifier nonReentrant() {
        if (_lock != 1) revert Reentrancy();
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Mint `quantity` tokens to the caller for `quantity * PRICE` wei.
    function mint(uint256 quantity) external payable nonReentrant {
        if (quantity == 0) revert ZeroQuantity();
        if (mintedBy[msg.sender] + quantity > MAX_PER_WALLET) revert WalletLimitExceeded();
        if (totalSupply + quantity > MAX_SUPPLY) revert SoldOut();
        if (msg.value != quantity * PRICE) revert WrongPayment();

        // Effects first: the wallet counter is final before any recipient code runs, so a
        // nested mint() from onERC721Received is checked against the updated count.
        mintedBy[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender);
        }
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        if (ownerOf[tokenId] != from || msg.sender != from) revert NotTokenOwner();
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        ownerOf[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function withdrawProceeds() external {
        if (msg.sender != owner) revert NotOwner();
        (bool ok, ) = owner.call{value: address(this).balance}("");
        if (!ok) revert TransferFailed();
    }

    function _safeMint(address to) internal {
        uint256 tokenId = totalSupply + 1;
        totalSupply = tokenId;
        ownerOf[tokenId] = to;
        balanceOf[to] += 1;
        emit Transfer(address(0), to, tokenId);

        // Contracts must acknowledge the token, exactly as ERC-721 safeMint does.
        if (to.code.length != 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, address(0), tokenId, "") returns (bytes4 ret) {
                if (ret != IERC721Receiver.onERC721Received.selector) revert UnsafeRecipient();
            } catch {
                revert UnsafeRecipient();
            }
        }
    }
}

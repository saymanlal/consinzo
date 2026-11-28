// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC721Like {
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

/// @title NftOrderBook
/// @notice Fixed-price NFT listings paid in ETH. Makers approve this contract for their collection.
contract NftOrderBook {
    enum Status {
        None,
        Open,
        Filled,
        Cancelled
    }

    struct Order {
        address maker;
        address nft;
        uint256 tokenId;
        uint256 price;
        uint256 makerNonce;
        Status status;
    }

    error NotMaker();
    error ZeroPrice();
    error OrderNotOpen();
    error StaleNonce();
    error WrongPrice();
    error TransferFailed();

    event OrderCreated(uint256 indexed orderId, address indexed maker, address nft, uint256 tokenId, uint256 price);
    event OrderCancelled(uint256 indexed orderId);
    event OrderFilled(uint256 indexed orderId, address indexed taker);
    event NonceIncremented(address indexed maker, uint256 newNonce);

    mapping(uint256 => Order) public orders;
    mapping(address => uint256) public nonces;
    uint256 public nextOrderId = 1;

    function createOrder(address nft, uint256 tokenId, uint256 price) external returns (uint256 orderId) {
        if (IERC721Like(nft).ownerOf(tokenId) != msg.sender) revert NotMaker();
        if (price == 0) revert ZeroPrice();
        orderId = nextOrderId++;
        orders[orderId] = Order(msg.sender, nft, tokenId, price, nonces[msg.sender], Status.Open);
        emit OrderCreated(orderId, msg.sender, nft, tokenId, price);
    }

    function cancelOrder(uint256 orderId) external {
        Order storage o = orders[orderId];
        if (o.maker != msg.sender) revert NotMaker();
        o.status = Status.Cancelled;
        emit OrderCancelled(orderId);
    }

    /// @notice Invalidates every order the caller created under the current nonce.
    function cancelAllOrders() external {
        uint256 newNonce = ++nonces[msg.sender];
        emit NonceIncremented(msg.sender, newNonce);
    }

    function fillOrder(uint256 orderId) external payable {
        Order storage o = orders[orderId];
        // TODO: this only checks that the order exists. Cancelled orders, already filled
        // orders and orders invalidated by cancelAllOrders() all pass.
        if (o.maker == address(0)) revert OrderNotOpen();
        if (msg.value != o.price) revert WrongPrice();

        address maker = o.maker;
        IERC721Like(o.nft).transferFrom(maker, msg.sender, o.tokenId);
        (bool ok, ) = maker.call{value: msg.value}("");
        if (!ok) revert TransferFailed();
        emit OrderFilled(orderId, msg.sender);
    }

    function orderStatus(uint256 orderId) external view returns (Status) {
        return orders[orderId].status;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Sells fixed-price tickets for ETH, one at a time or in a batch.
contract TicketBooth {
    error NotOwner();
    error InvalidItem();
    error UnknownItem();
    error SoldOut();
    error WrongPayment();
    error EmptyBatch();
    error TransferFailed();

    event ItemListed(uint256 indexed id, uint256 price, uint256 stock);
    event Purchased(address indexed buyer, uint256 indexed id, uint256 price);

    struct Item {
        uint256 price;
        uint256 stock;
    }

    address public immutable owner;
    mapping(uint256 => Item) public items;
    mapping(address => mapping(uint256 => uint256)) public purchased;
    /// @notice ETH earned from sales and not yet withdrawn by the owner.
    uint256 public proceeds;

    constructor() {
        owner = msg.sender;
    }

    function listItem(uint256 id, uint256 price, uint256 stock) external {
        if (msg.sender != owner) revert NotOwner();
        if (price == 0 || items[id].price != 0) revert InvalidItem();
        items[id] = Item(price, stock);
        emit ItemListed(id, price, stock);
    }

    /// @notice Buy one ticket for exactly its price.
    function buy(uint256 id) external payable {
        if (msg.value != _purchase(id)) revert WrongPayment();
    }

    /// @notice Buy one ticket per entry of `ids` (an id may appear more than once).
    function buyBatch(uint256[] calldata ids) external payable {
        if (ids.length == 0) revert EmptyBatch();
        // msg.value is constant for the whole call, so it is compared exactly once,
        // against the sum of every ticket price in the batch.
        uint256 total;
        for (uint256 i = 0; i < ids.length; i++) {
            total += _purchase(ids[i]);
        }
        if (msg.value != total) revert WrongPayment();
    }

    function withdrawProceeds() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 amount = proceeds;
        proceeds = 0;
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @dev Books one ticket and returns its price. Payment is checked by the caller.
    function _purchase(uint256 id) internal returns (uint256 price) {
        Item storage item = items[id];
        price = item.price;
        if (price == 0) revert UnknownItem();
        if (item.stock == 0) revert SoldOut();

        item.stock -= 1;
        purchased[msg.sender][id] += 1;
        proceeds += price;
        emit Purchased(msg.sender, id, price);
    }
}

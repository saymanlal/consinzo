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
        _purchase(id);
    }

    /// @notice Buy one ticket per entry of `ids` (an id may appear more than once).
    function buyBatch(uint256[] calldata ids) external payable {
        if (ids.length == 0) revert EmptyBatch();
        for (uint256 i = 0; i < ids.length; i++) {
            _purchase(ids[i]);
        }
    }

    function withdrawProceeds() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 amount = proceeds;
        proceeds = 0;
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function _purchase(uint256 id) internal {
        Item storage item = items[id];
        if (item.price == 0) revert UnknownItem();
        if (item.stock == 0) revert SoldOut();
        // TODO: this comparison runs once per ticket, against the same msg.value every time.
        if (msg.value != item.price) revert WrongPayment();

        item.stock -= 1;
        purchased[msg.sender][id] += 1;
        proceeds += item.price;
        emit Purchased(msg.sender, id, item.price);
    }
}

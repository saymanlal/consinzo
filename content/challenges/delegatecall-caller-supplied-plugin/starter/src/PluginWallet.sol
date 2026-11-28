// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Stateless plugin: pays several recipients from the calling wallet's balance.
/// @dev Meant to be executed with delegatecall, so `address(this)` is the wallet.
contract BatchPayPlugin {
    error LengthMismatch();
    error PayFailed();

    function pay(address payable[] calldata recipients, uint256[] calldata amounts) external {
        if (recipients.length != amounts.length) revert LengthMismatch();
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool ok, ) = recipients[i].call{value: amounts[i]}("");
            if (!ok) revert PayFailed();
        }
    }
}

/// @notice ETH wallet that gains features by delegatecalling plugin contracts.
contract PluginWallet {
    error NotOwner();
    error ZeroAddress();
    error NotAContract();
    error PluginNotApproved();
    error PluginFailed();

    event PluginSet(address indexed plugin, bool approved);
    event PluginRun(address indexed plugin, bytes4 indexed selector);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public owner;
    mapping(address => bool) public approvedPlugin;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() payable {
        owner = msg.sender;
    }

    receive() external payable {}

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Approve or revoke a plugin. Only contracts can be approved.
    function setPlugin(address plugin, bool approved) external onlyOwner {
        if (approved && plugin.code.length == 0) revert NotAContract();
        approvedPlugin[plugin] = approved;
        emit PluginSet(plugin, approved);
    }

    /// @notice Execute `data` on `plugin` in the context of this wallet.
    function run(address plugin, bytes calldata data) external returns (bytes memory result) {
        // TODO: `plugin` and `data` are fully controlled by the caller.
        (bool ok, bytes memory ret) = plugin.delegatecall(data);
        if (!ok) revert PluginFailed();
        emit PluginRun(plugin, bytes4(data));
        return ret;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Wallet logic used behind ERC-1167 minimal proxies (clones).
/// Clones do not run constructors, so ownership is set through `initialize`.
contract CloneWallet {
    error AlreadyInitialized();
    error ZeroAddress();
    error NotOwner();
    error TransferFailed();

    address public owner;
    bool public initialized;

    // TODO: decide who may call this, and when.
    function initialize(address owner_) external {
        if (initialized) revert AlreadyInitialized();
        if (owner_ == address(0)) revert ZeroAddress();
        initialized = true;
        owner = owner_;
    }

    receive() external payable {}

    function withdraw(address payable to, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}

/// @notice Deploys deterministic CloneWallet proxies.
contract WalletFactory {
    error CloneFailed();

    event WalletCreated(address indexed creator, address indexed wallet, bytes32 salt);

    address public immutable implementation;
    mapping(address => bool) public isWallet;

    constructor() {
        implementation = address(new CloneWallet());
    }

    /// @notice Address at which `creator`'s wallet for `salt` will be deployed.
    function predict(address creator, bytes32 salt) public view returns (address) {
        // TODO: `creator` is ignored, so every user shares the same address per salt.
        creator;
        return _predict(salt);
    }

    /// @notice Deploy a wallet for the caller.
    function createWallet(bytes32 salt) external returns (address wallet) {
        wallet = _clone(salt);
        isWallet[wallet] = true;
        emit WalletCreated(msg.sender, wallet, salt);
        // TODO: the creator is expected to call `initialize` in a follow-up transaction.
    }

    // ---------------------------------------------------------------- internals

    /// @dev ERC-1167 creation code for `implementation`.
    function _initCode() internal view returns (bytes memory) {
        return abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
    }

    function _clone(bytes32 finalSalt) internal returns (address instance) {
        bytes memory code = _initCode();
        assembly {
            instance := create2(0, add(code, 0x20), mload(code), finalSalt)
        }
        if (instance == address(0)) revert CloneFailed();
    }

    function _predict(bytes32 finalSalt) internal view returns (address) {
        bytes32 h = keccak256(abi.encodePacked(bytes1(0xff), address(this), finalSalt, keccak256(_initCode())));
        return address(uint160(uint256(h)));
    }
}

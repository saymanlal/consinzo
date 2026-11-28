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

    /// @dev Runs only for the implementation (clones never execute constructors).
    /// Locking it means the template itself can never be given an owner.
    constructor() {
        initialized = true;
    }

    /// @dev One-shot. The factory calls this in the same transaction that deploys the
    /// clone, so there is no moment at which an uninitialised wallet is reachable.
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
        return _predict(_saltFor(creator, salt));
    }

    /// @notice Deploy a wallet for the caller.
    function createWallet(bytes32 salt) external returns (address wallet) {
        // The creator is part of the CREATE2 salt: nobody else can deploy to this address.
        wallet = _clone(_saltFor(msg.sender, salt));
        isWallet[wallet] = true;
        // Deploy and initialise atomically, with the owner fixed to the caller.
        CloneWallet(payable(wallet)).initialize(msg.sender);
        emit WalletCreated(msg.sender, wallet, salt);
    }

    // ---------------------------------------------------------------- internals

    function _saltFor(address creator, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(creator, salt));
    }

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

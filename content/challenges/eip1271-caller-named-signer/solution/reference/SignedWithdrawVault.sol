// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}

/// @title SignedWithdrawVault
/// @notice ETH vault for contract wallets with relayed, EIP-1271 authorised withdrawals.
contract SignedWithdrawVault {
    bytes4 private constant ERC1271_MAGIC = 0x1626ba7e;
    bytes32 public constant WITHDRAWAL_TYPEHASH =
        keccak256("Withdrawal(address account,address to,uint256 amount,uint256 nonce,uint256 deadline)");

    struct Withdrawal {
        address account;
        address to;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    error ZeroAmount();
    error InsufficientBalance();
    error Expired();
    error InvalidNonce();
    error UnauthorizedSigner();
    error InvalidSignature();
    error TransferFailed();

    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, address indexed to, uint256 amount);
    event DelegateSet(address indexed account, address indexed signer, bool allowed);

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public nonces;
    mapping(address => mapping(address => bool)) public isDelegate;

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        balanceOf[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _debit(msg.sender, amount);
        _send(msg.sender, msg.sender, amount);
    }

    /// @notice Lets `signer` (an EIP-1271 contract) authorise withdrawals for the caller.
    function setDelegate(address signer, bool allowed) external {
        isDelegate[msg.sender][signer] = allowed;
        emit DelegateSet(msg.sender, signer, allowed);
    }

    function hashWithdrawal(Withdrawal calldata w) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(WITHDRAWAL_TYPEHASH, block.chainid, address(this), w.account, w.to, w.amount, w.nonce, w.deadline)
            );
    }

    function withdrawWithSignature(Withdrawal calldata w, address signer, bytes calldata signature) external {
        if (block.timestamp > w.deadline) revert Expired();
        if (w.nonce != nonces[w.account]) revert InvalidNonce();
        // The relayer names the signer, so the name carries no authority by itself. Authority
        // exists only if the debited account is the signer or has registered it.
        if (signer != w.account && !isDelegate[w.account][signer]) revert UnauthorizedSigner();
        if (!_isValidSignatureNow(signer, hashWithdrawal(w), signature)) revert InvalidSignature();

        nonces[w.account] = w.nonce + 1;
        _debit(w.account, w.amount);
        _send(w.account, w.to, w.amount);
    }

    /// @dev EIP-1271 query that cannot be turned against the vault: static, no bubbling of
    ///      the signer's revert data, and strict about the shape of the answer.
    function _isValidSignatureNow(address signer, bytes32 hash, bytes calldata signature) private view returns (bool) {
        (bool ok, bytes memory ret) = signer.staticcall(abi.encodeCall(IERC1271.isValidSignature, (hash, signature)));
        // An account without code "succeeds" with empty return data; the length check rejects it.
        return ok && ret.length >= 32 && bytes32(ret) == bytes32(ERC1271_MAGIC);
    }

    function _debit(address account, uint256 amount) private {
        if (amount == 0) revert ZeroAmount();
        if (amount > balanceOf[account]) revert InsufficientBalance();
        balanceOf[account] -= amount;
    }

    function _send(address account, address to, uint256 amount) private {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(account, to, amount);
    }
}

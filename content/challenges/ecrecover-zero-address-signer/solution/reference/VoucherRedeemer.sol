// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Pays out ETH vouchers signed off-chain by a designated signer.
/// @dev The signer is configured after deployment and can be cleared to pause redemptions.
contract VoucherRedeemer {
    error NotOwner();
    error ZeroSigner();
    error SignerNotSet();
    error InvalidSignature();
    error VoucherUsed();
    error TransferFailed();

    event SignerSet(address indexed signer);
    event Redeemed(address indexed to, uint256 amount, uint256 indexed nonce);

    address public immutable owner;
    /// @notice Voucher signer. `address(0)` means "not configured / paused".
    address public signer;
    mapping(uint256 => bool) public usedNonce;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() payable {
        owner = msg.sender;
    }

    receive() external payable {}

    function setSigner(address newSigner) external onlyOwner {
        // address(0) is the "no signer" marker and must only be reachable via clearSigner().
        if (newSigner == address(0)) revert ZeroSigner();
        signer = newSigner;
        emit SignerSet(newSigner);
    }

    /// @notice Pause redemptions by removing the signer.
    function clearSigner() external onlyOwner {
        signer = address(0);
        emit SignerSet(address(0));
    }

    /// @notice Digest the signer signs for a voucher (EIP-191 personal message).
    function voucherDigest(address to, uint256 amount, uint256 nonce) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(block.chainid, address(this), to, amount, nonce));
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", structHash));
    }

    /// @notice Redeem a voucher issued to the caller.
    function redeem(uint256 amount, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external {
        if (usedNonce[nonce]) revert VoucherUsed();

        // No signer configured (fresh deployment or paused): nothing can be valid.
        address expected = signer;
        if (expected == address(0)) revert SignerNotSet();

        // ecrecover signals failure by returning address(0) instead of reverting.
        address recovered = ecrecover(voucherDigest(msg.sender, amount, nonce), v, r, s);
        if (recovered == address(0) || recovered != expected) revert InvalidSignature();

        usedNonce[nonce] = true;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Redeemed(msg.sender, amount, nonce);
    }
}

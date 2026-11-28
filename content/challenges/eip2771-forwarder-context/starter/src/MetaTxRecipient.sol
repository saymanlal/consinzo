// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MetaTxRecipient {
    error ZeroAddress();
    error NotOwner();
    error InsufficientBalance();
    error TransferFailed();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Deposited(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event NoteSet(address indexed account, string note);

    address public immutable trustedForwarder;
    address public owner;
    mapping(address => uint256) public balanceOf;
    mapping(address => string) public noteOf;

    constructor(address forwarder) {
        // TODO: reject the zero address.
        trustedForwarder = forwarder;
        owner = msg.sender;
    }

    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == trustedForwarder;
    }

    /// @dev Effective sender according to EIP-2771.
    function _msgSender() internal view returns (address) {
        // TODO: return the appended address when called by the trusted forwarder
        //       with at least 20 bytes of calldata.
        return msg.sender;
    }

    /// @dev Effective calldata according to EIP-2771.
    function _msgData() internal view returns (bytes calldata) {
        // TODO: strip the appended address in the forwarded case.
        return msg.data;
    }

    function context() external view returns (address sender, bytes memory data) {
        return (_msgSender(), _msgData());
    }

    function transferOwnership(address newOwner) external {
        // TODO: only the owner (as effective sender), no zero address.
        revert("NOT_IMPLEMENTED");
    }

    function deposit() external payable {
        // TODO: credit the effective sender.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 amount) external {
        // TODO: debit the effective sender and send the ether to it.
        revert("NOT_IMPLEMENTED");
    }

    function setNote(string calldata note) external {
        // TODO: store the note for the effective sender.
        revert("NOT_IMPLEMENTED");
    }
}

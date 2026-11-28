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

    uint256 private constant SUFFIX_LENGTH = 20;

    address public immutable trustedForwarder;
    address public owner;
    mapping(address => uint256) public balanceOf;
    mapping(address => string) public noteOf;

    constructor(address forwarder) {
        if (forwarder == address(0)) revert ZeroAddress();
        trustedForwarder = forwarder;
        owner = msg.sender;
    }

    function isTrustedForwarder(address forwarder) public view returns (bool) {
        return forwarder == trustedForwarder;
    }

    /// @dev True when the call was relayed: it comes from the forwarder and is long enough
    /// to carry an appended address. Both conditions are required. Without the caller check
    /// anyone could impersonate any account; without the length check a short call from the
    /// forwarder would read out of bounds.
    function _isForwarded() private view returns (bool) {
        return msg.sender == trustedForwarder && msg.data.length >= SUFFIX_LENGTH;
    }

    function _msgSender() internal view returns (address) {
        if (_isForwarded()) {
            return address(bytes20(msg.data[msg.data.length - SUFFIX_LENGTH:]));
        }
        return msg.sender;
    }

    function _msgData() internal view returns (bytes calldata) {
        if (_isForwarded()) {
            return msg.data[:msg.data.length - SUFFIX_LENGTH];
        }
        return msg.data;
    }

    function context() external view returns (address sender, bytes memory data) {
        return (_msgSender(), _msgData());
    }

    function transferOwnership(address newOwner) external {
        if (_msgSender() != owner) revert NotOwner();
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function deposit() external payable {
        address sender = _msgSender();
        balanceOf[sender] += msg.value;
        emit Deposited(sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        address sender = _msgSender();
        uint256 balance = balanceOf[sender];
        if (balance < amount) revert InsufficientBalance();
        // Effects before the external call.
        balanceOf[sender] = balance - amount;
        emit Withdrawn(sender, amount);
        // The ether goes to the effective sender, never to the relaying forwarder.
        (bool ok,) = sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    function setNote(string calldata note) external {
        address sender = _msgSender();
        noteOf[sender] = note;
        emit NoteSet(sender, note);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract AddressBook {
    error ZeroAddress();
    error EmptyLabel();
    error EntryNotFound(address owner, address account);

    event LabelSet(address indexed owner, address indexed account, string label);
    event LabelRemoved(address indexed owner, address indexed account);

    // owner => account => label
    mapping(address => mapping(address => string)) private _labels;
    mapping(address => uint256) public entryCount;

    function setLabel(address account, string calldata label) external {
        // TODO: validate inputs, store the label in msg.sender's book,
        // keep entryCount correct and emit LabelSet
        revert("NOT_IMPLEMENTED");
    }

    function removeLabel(address account) external {
        // TODO: revert with EntryNotFound if missing, otherwise delete and emit LabelRemoved
        revert("NOT_IMPLEMENTED");
    }

    function getLabel(address owner, address account) external view returns (string memory) {
        // TODO: return the label or revert with EntryNotFound(owner, account)
        return "";
    }

    function hasLabel(address owner, address account) external view returns (bool) {
        // TODO: report whether owner stored a label for account
        return false;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract AddressBook {
    error ZeroAddress();
    error EmptyLabel();
    error EntryNotFound(address owner, address account);

    event LabelSet(address indexed owner, address indexed account, string label);
    event LabelRemoved(address indexed owner, address indexed account);

    // owner => account => label. Empty labels are rejected on write,
    // so an empty stored string means "no entry".
    mapping(address => mapping(address => string)) private _labels;
    mapping(address => uint256) public entryCount;

    function setLabel(address account, string calldata label) external {
        if (account == address(0)) revert ZeroAddress();
        if (bytes(label).length == 0) revert EmptyLabel();

        // Only a brand-new entry changes the count; an overwrite does not.
        if (!_exists(msg.sender, account)) {
            entryCount[msg.sender] += 1;
        }
        _labels[msg.sender][account] = label;

        emit LabelSet(msg.sender, account, label);
    }

    function removeLabel(address account) external {
        if (!_exists(msg.sender, account)) revert EntryNotFound(msg.sender, account);

        delete _labels[msg.sender][account];
        entryCount[msg.sender] -= 1;

        emit LabelRemoved(msg.sender, account);
    }

    function getLabel(address owner, address account) external view returns (string memory) {
        if (!_exists(owner, account)) revert EntryNotFound(owner, account);
        return _labels[owner][account];
    }

    function hasLabel(address owner, address account) external view returns (bool) {
        return _exists(owner, account);
    }

    function _exists(address owner, address account) internal view returns (bool) {
        return bytes(_labels[owner][account]).length != 0;
    }
}

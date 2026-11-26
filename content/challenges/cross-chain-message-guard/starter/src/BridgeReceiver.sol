// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BridgeReceiver {
    address public immutable relayer;
    mapping(uint256 => address) public trustedRemote;
    mapping(bytes32 => bool) public processed;
    mapping(address => uint256) public credited;

    constructor(address _relayer, uint256 _srcChainId, address _srcSender) {
        relayer = _relayer;
        trustedRemote[_srcChainId] = _srcSender;
    }

    function receiveMessage(uint256 srcChainId, address srcSender, bytes32 msgId, address recipient, uint256 amount) external {
        // VULNERABLE: No relayer check, no trustedRemote check, no replay check!
        credited[recipient] += amount;
    }
}
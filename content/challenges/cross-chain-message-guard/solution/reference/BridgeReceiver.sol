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
        require(msg.sender == relayer, "ONLY_RELAYER");
        require(srcSender != address(0) && trustedRemote[srcChainId] == srcSender, "UNTRUSTED_SOURCE");
        require(!processed[msgId], "ALREADY_PROCESSED");
        require(recipient != address(0), "ZERO_RECIPIENT");
        processed[msgId] = true;
        credited[recipient] += amount;
    }
}
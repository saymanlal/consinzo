// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract EtherRouter {
    uint256 public receiveCount;
    uint256 public fallbackCount;
    uint256 public totalViaReceive;
    uint256 public totalViaFallback;
    bytes4 public lastUnknownSelector;
    mapping(address => uint256) public contributionOf;

    event Received(address indexed from, uint256 amount);
    event UnknownCall(address indexed from, bytes4 selector, uint256 amount);

    /// Runs only when the calldata is empty.
    receive() external payable {
        receiveCount += 1;
        totalViaReceive += msg.value;
        contributionOf[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    /// Runs when the calldata is not empty and matches no function selector.
    /// It is payable so that an unknown call may carry value.
    fallback() external payable {
        fallbackCount += 1;
        totalViaFallback += msg.value;
        contributionOf[msg.sender] += msg.value;
        // msg.sig is the first four bytes of calldata, zero-padded when fewer were sent.
        lastUnknownSelector = msg.sig;
        emit UnknownCall(msg.sender, msg.sig, msg.value);
    }

    function ping() external pure returns (bytes4) {
        return this.ping.selector;
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}

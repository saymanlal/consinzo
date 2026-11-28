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

    // TODO: add `receive() external payable` for calls with empty calldata.
    //       Count the transfer, add the value to the totals and emit Received.

    // TODO: add `fallback() external payable` for calls that match no function.
    //       Count the call, add the value to the totals, record msg.sig and emit UnknownCall.

    function ping() external pure returns (bytes4) {
        // TODO: return this function's own selector
        revert("NOT_IMPLEMENTED");
    }

    function balance() external view returns (uint256) {
        // TODO: return the Ether held by this contract
        revert("NOT_IMPLEMENTED");
    }
}

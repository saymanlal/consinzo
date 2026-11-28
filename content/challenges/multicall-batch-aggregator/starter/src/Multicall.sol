// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Multicall {
    struct Call {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    error TargetNotContract(uint256 index);
    error CallFailed(uint256 index, bytes returnData);

    function aggregate(Call[] calldata calls)
        external
        returns (uint256 blockNumber, Result[] memory results)
    {
        // TODO: execute every call in order.
        // TODO: revert with TargetNotContract(i) when calls[i].target has no code.
        // TODO: revert with CallFailed(i, returnData) when a call fails and allowFailure is false.
        // TODO: return block.number and one Result per call.
        revert("NOT_IMPLEMENTED");
    }
}

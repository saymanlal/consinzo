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
        blockNumber = block.number;
        uint256 length = calls.length;
        results = new Result[](length);

        for (uint256 i = 0; i < length; ++i) {
            Call calldata c = calls[i];

            // A low-level call to an address without code succeeds with empty return data.
            // Reporting that as a success would hide mistakes, so reject it up front.
            if (c.target.code.length == 0) revert TargetNotContract(i);

            (bool success, bytes memory returnData) = c.target.call(c.callData);
            if (!success && !c.allowFailure) revert CallFailed(i, returnData);

            results[i] = Result({success: success, returnData: returnData});
        }
    }
}

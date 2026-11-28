// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RunningStats {
    error NoData();

    event Submitted(address indexed by, uint256 value);

    uint256 public count;
    uint256 public sum;

    // TODO: add the state needed to track the minimum and maximum

    function submit(uint256 value) external {
        // TODO: update count, sum, min and max; emit Submitted
        revert("NOT_IMPLEMENTED");
    }

    function submitBatch(uint256[] calldata values) external {
        // TODO: same as calling submit for every element in order
        revert("NOT_IMPLEMENTED");
    }

    function min() external view returns (uint256) {
        // TODO: revert with NoData() when nothing was submitted
        return 0;
    }

    function max() external view returns (uint256) {
        // TODO: revert with NoData() when nothing was submitted
        return 0;
    }

    function average() external view returns (uint256) {
        // TODO: sum / count rounded down; revert with NoData() when nothing was submitted
        return 0;
    }
}

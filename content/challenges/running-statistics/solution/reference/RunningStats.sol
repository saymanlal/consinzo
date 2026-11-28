// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract RunningStats {
    error NoData();

    event Submitted(address indexed by, uint256 value);

    uint256 public count;
    uint256 public sum;

    uint256 private _min;
    uint256 private _max;

    modifier hasData() {
        if (count == 0) revert NoData();
        _;
    }

    function submit(uint256 value) external {
        _submit(value);
    }

    function submitBatch(uint256[] calldata values) external {
        uint256 length = values.length;
        for (uint256 i = 0; i < length; i++) {
            _submit(values[i]);
        }
    }

    function min() external view hasData returns (uint256) {
        return _min;
    }

    function max() external view hasData returns (uint256) {
        return _max;
    }

    function average() external view hasData returns (uint256) {
        // Integer division rounds down. hasData guarantees count != 0.
        return sum / count;
    }

    function _submit(uint256 value) internal {
        if (count == 0) {
            // The first value defines both extremes. Comparing it with the
            // zero-initialised storage would leave the minimum stuck at 0.
            _min = value;
            _max = value;
        } else if (value < _min) {
            _min = value;
        } else if (value > _max) {
            _max = value;
        }

        count += 1;
        sum += value;

        emit Submitted(msg.sender, value);
    }
}

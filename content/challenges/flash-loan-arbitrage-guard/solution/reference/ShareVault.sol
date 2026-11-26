// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ShareVault {
    uint256 public totalShares;
    uint256 private _managedAssets;
    mapping(address => uint256) public sharesOf;

    receive() external payable {}

    function totalAssets() public view returns (uint256) {
        return _managedAssets;
    }

    function deposit() external payable returns (uint256 minted) {
        require(msg.value > 0, "ZERO_DEPOSIT");
        if (totalShares == 0 || _managedAssets == 0) {
            minted = msg.value;
        } else {
            minted = (msg.value * totalShares) / _managedAssets;
        }
        require(minted > 0, "ZERO_SHARES");
        _managedAssets += msg.value;
        sharesOf[msg.sender] += minted;
        totalShares += minted;
    }

    function withdraw(uint256 shareAmount) external returns (uint256 assetsOut) {
        require(shareAmount > 0 && sharesOf[msg.sender] >= shareAmount, "INVALID_SHARES");
        assetsOut = (shareAmount * _managedAssets) / totalShares;
        sharesOf[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        _managedAssets -= assetsOut;
        (bool ok, ) = msg.sender.call{value: assetsOut}("");
        require(ok, "TRANSFER_FAILED");
    }
}

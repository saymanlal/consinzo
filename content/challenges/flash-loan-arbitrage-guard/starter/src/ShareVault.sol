// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ShareVault {
    uint256 public totalShares;
    mapping(address => uint256) public sharesOf;

    receive() external payable {}

    function totalAssets() public view returns (uint256) {
        // VULNERABLE: Raw balance can be manipulated via unsolicited ETH transfers
        return address(this).balance;
    }

    function deposit() external payable returns (uint256 minted) {
        require(msg.value > 0, "ZERO_DEPOSIT");
        uint256 assetsBefore = totalAssets() - msg.value;
        if (totalShares == 0) {
            minted = msg.value;
        } else {
            minted = (msg.value * totalShares) / assetsBefore;
        }
        sharesOf[msg.sender] += minted;
        totalShares += minted;
    }

    function withdraw(uint256 shareAmount) external returns (uint256 assetsOut) {
        require(shareAmount > 0 && sharesOf[msg.sender] >= shareAmount, "INVALID_SHARES");
        assetsOut = (shareAmount * totalAssets()) / totalShares;
        sharesOf[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        (bool ok, ) = msg.sender.call{value: assetsOut}("");
        require(ok, "TRANSFER_FAILED");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IAssetERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenizedVault {
    IAssetERC20 public immutable asset;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _asset) {
        asset = IAssetERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        revert("NOT_IMPLEMENTED");
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        revert("NOT_IMPLEMENTED");
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        revert("NOT_IMPLEMENTED");
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        revert("NOT_IMPLEMENTED");
    }
}

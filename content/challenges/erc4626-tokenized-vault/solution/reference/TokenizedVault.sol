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

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares);

    constructor(address _asset) {
        require(_asset != address(0), "ZERO_ASSET");
        asset = IAssetERC20(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        require(assets > 0 && receiver != address(0), "INVALID_DEPOSIT");
        shares = convertToShares(assets);
        require(shares > 0, "ZERO_SHARES");
        require(asset.transferFrom(msg.sender, address(this), assets), "PULL_FAILED");
        balanceOf[receiver] += shares;
        totalSupply += shares;
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(shares > 0 && receiver != address(0), "INVALID_REDEEM");
        require(msg.sender == owner, "NOT_OWNER");
        require(balanceOf[owner] >= shares, "INSUFFICIENT_SHARES");
        assets = convertToAssets(shares);
        require(assets > 0, "ZERO_ASSETS");
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        require(asset.transfer(receiver, assets), "SEND_FAILED");
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}

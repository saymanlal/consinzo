// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenSale.sol";

contract MockERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract TokenSaleTest is Test {
    MockERC20 public token;
    TokenSale public sale;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    receive() external payable {}

    function setUp() public {
        token = new MockERC20();
        // 2000 tokens per ETH, 10 ETH hard cap, 4 ETH per buyer
        sale = new TokenSale(address(token), 2000 ether, 10 ether, 4 ether);
        token.mint(address(sale), 20_000 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function testConfiguration() public view {
        assertEq(sale.owner(), address(this));
        assertEq(sale.rate(), 2000 ether);
        assertEq(sale.hardCap(), 10 ether);
        assertEq(sale.buyerLimit(), 4 ether);
        assertEq(sale.tokensFor(1 ether), 2000 ether);
        assertEq(sale.remainingCap(), 10 ether);
    }

    function testBuyTransfersTokensAtRate() public {
        vm.prank(alice);
        sale.buy{value: 1.5 ether}();
        assertEq(token.balanceOf(alice), 3000 ether);
        assertEq(sale.totalRaised(), 1.5 ether);
        assertEq(sale.contributed(alice), 1.5 ether);
        assertEq(sale.remainingCap(), 8.5 ether);
        assertEq(address(sale).balance, 1.5 ether);
    }

    function testBuyerLimitEnforced() public {
        vm.prank(alice);
        sale.buy{value: 3 ether}();
        vm.prank(alice);
        vm.expectRevert(TokenSale.BuyerLimitExceeded.selector);
        sale.buy{value: 1 ether + 1}();
        vm.prank(alice);
        sale.buy{value: 1 ether}();
        assertEq(sale.contributed(alice), 4 ether);
    }

    function testOwnerWithdrawsProceeds() public {
        vm.prank(alice);
        sale.buy{value: 2 ether}();
        vm.prank(bob);
        sale.buy{value: 1 ether}();
        uint256 before = address(this).balance;
        sale.withdraw();
        assertEq(address(this).balance, before + 3 ether);
        assertEq(address(sale).balance, 0);
    }

    function testZeroValueReverts() public {
        vm.prank(alice);
        vm.expectRevert(TokenSale.ZeroAmount.selector);
        sale.buy{value: 0}();
    }
}

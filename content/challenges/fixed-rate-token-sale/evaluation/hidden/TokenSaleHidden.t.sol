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

contract TokenSaleHiddenTest is Test {
    MockERC20 public token;
    TokenSale public sale;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA201);

    receive() external payable {}

    function setUp() public {
        token = new MockERC20();
        // 1234.5 tokens per ETH, 9 ETH hard cap, 4 ETH per buyer
        sale = new TokenSale(address(token), 1234.5 ether, 9 ether, 4 ether);
        token.mint(address(sale), 50_000 ether);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carol, 100 ether);
    }

    function testHiddenRoundingDown() public {
        // 7 wei * 1234.5e18 / 1e18 = 8641.5 -> 8641
        assertEq(sale.tokensFor(7), 8641);
        vm.prank(alice);
        sale.buy{value: 7}();
        assertEq(token.balanceOf(alice), 8641);
        assertEq(sale.contributed(alice), 7);
    }

    function testHiddenHardCapExactBoundary() public {
        vm.prank(alice);
        sale.buy{value: 4 ether}();
        vm.prank(bob);
        sale.buy{value: 4 ether}();
        assertEq(sale.remainingCap(), 1 ether);

        vm.prank(carol);
        vm.expectRevert(TokenSale.HardCapExceeded.selector);
        sale.buy{value: 1 ether + 1}();

        vm.prank(carol);
        sale.buy{value: 1 ether}();
        assertEq(sale.totalRaised(), 9 ether);
        assertEq(sale.remainingCap(), 0);
        assertEq(token.balanceOf(carol), 1234.5 ether);

        vm.prank(carol);
        vm.expectRevert(TokenSale.HardCapExceeded.selector);
        sale.buy{value: 1}();
    }

    function testHiddenHardCapCheckedBeforeBuyerLimit() public {
        vm.prank(alice);
        sale.buy{value: 4 ether}();
        vm.prank(bob);
        sale.buy{value: 3 ether}();
        // bob: 3 + 2.5 breaks both caps; the hard cap error wins
        vm.prank(bob);
        vm.expectRevert(TokenSale.HardCapExceeded.selector);
        sale.buy{value: 2.5 ether}();
        // bob: 3 + 1.5 fits the hard cap but not the buyer limit
        vm.prank(bob);
        vm.expectRevert(TokenSale.BuyerLimitExceeded.selector);
        sale.buy{value: 1.5 ether}();
    }

    function testHiddenOnlyOwnerWithdraws() public {
        vm.prank(alice);
        sale.buy{value: 2 ether}();
        vm.prank(alice);
        vm.expectRevert(TokenSale.NotOwner.selector);
        sale.withdraw();
        assertEq(address(sale).balance, 2 ether);
    }

    function testHiddenWithdrawDoesNotReopenCap() public {
        vm.prank(alice);
        sale.buy{value: 4 ether}();
        vm.prank(bob);
        sale.buy{value: 4 ether}();
        sale.withdraw();
        assertEq(sale.totalRaised(), 8 ether);
        assertEq(sale.contributed(alice), 4 ether);

        vm.prank(alice);
        vm.expectRevert(TokenSale.BuyerLimitExceeded.selector);
        sale.buy{value: 1}();
        vm.prank(carol);
        vm.expectRevert(TokenSale.HardCapExceeded.selector);
        sale.buy{value: 2 ether}();
        vm.prank(carol);
        sale.buy{value: 1 ether}();
        assertEq(address(sale).balance, 1 ether);
    }

    function testHiddenRevertsWhenInventoryRunsOut() public {
        MockERC20 small = new MockERC20();
        TokenSale s = new TokenSale(address(small), 1000 ether, 9 ether, 4 ether);
        small.mint(address(s), 500 ether);
        vm.prank(alice);
        vm.expectRevert();
        s.buy{value: 1 ether}();
        assertEq(s.totalRaised(), 0);
        vm.prank(alice);
        s.buy{value: 0.5 ether}();
        assertEq(small.balanceOf(alice), 500 ether);
    }
}

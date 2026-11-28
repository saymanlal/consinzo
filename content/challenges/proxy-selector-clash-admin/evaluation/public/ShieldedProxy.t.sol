// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ShieldedProxy.sol";

interface IProxyAdmin {
    function admin() external view returns (address);
    function implementation() external view returns (address);
    function upgradeTo(address newImplementation) external;
    function changeAdmin(address newAdmin) external;
}

/// ETH-backed token used as the implementation. Its state lives in the proxy.
contract WrappedToken {
    error InsufficientBalance();

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    receive() external payable {
        deposit();
    }

    function burn(uint256 amount) external {
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH");
    }

    function version() external pure virtual returns (uint256) {
        return 1;
    }
}

contract WrappedTokenV2 is WrappedToken {
    function version() external pure override returns (uint256) {
        return 2;
    }
}

/// What an attacker would upgrade to.
contract SweepImpl {
    function sweep(address payable to) external {
        to.transfer(address(this).balance);
    }
}

abstract contract ProxyFixture is Test {
    ShieldedProxy internal proxy;
    WrappedToken internal token; // the proxy, seen through the token ABI
    IProxyAdmin internal adminView; // the proxy, seen through the admin ABI
    WrappedToken internal impl;
    address internal proxyAdmin = address(0xAD);
    address internal alice = address(0xA11CE);
    address internal attacker = address(0xBAD);

    function _deploy() internal {
        impl = new WrappedToken();
        proxy = new ShieldedProxy(address(impl), proxyAdmin);
        token = WrappedToken(payable(address(proxy)));
        adminView = IProxyAdmin(address(proxy));
        vm.deal(alice, 100 ether);
        vm.deal(attacker, 1 ether);
        vm.prank(alice);
        token.deposit{value: 10 ether}();
    }

    function _admin() internal returns (address a) {
        vm.prank(proxyAdmin);
        a = adminView.admin();
    }

    function _implementation() internal returns (address a) {
        vm.prank(proxyAdmin);
        a = adminView.implementation();
    }
}

contract ShieldedProxyTest is ProxyFixture {
    function setUp() public {
        _deploy();
    }

    function testBurnThroughProxyBurnsTokens() public {
        vm.prank(alice);
        token.burn(4 ether);
        assertEq(token.balanceOf(alice), 6 ether);
        assertEq(token.totalSupply(), 6 ether);
        assertEq(alice.balance, 94 ether);
        assertEq(address(proxy).balance, 6 ether);
    }

    function testBurnDoesNotHandOverTheProxy() public {
        vm.prank(attacker);
        token.burn(0);
        assertEq(_admin(), proxyAdmin);

        SweepImpl evil = new SweepImpl();
        vm.prank(attacker);
        vm.expectRevert();
        adminView.upgradeTo(address(evil));
        assertEq(_implementation(), address(impl));
        assertEq(address(proxy).balance, 10 ether);
    }

    function testAdminUpgradesAndStateSurvives() public {
        WrappedTokenV2 v2 = new WrappedTokenV2();
        vm.prank(proxyAdmin);
        adminView.upgradeTo(address(v2));
        assertEq(_implementation(), address(v2));
        assertEq(token.version(), 2);
        assertEq(token.balanceOf(alice), 10 ether);
    }

    function testAdminCannotUseTheImplementation() public {
        vm.deal(proxyAdmin, 1 ether);
        vm.prank(proxyAdmin);
        vm.expectRevert(ShieldedProxy.AdminCannotFallback.selector);
        token.deposit{value: 1 ether}();
    }
}

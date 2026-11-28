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

/// An implementation whose own functions use the same selectors as the proxy admin interface.
contract ClashingImpl {
    address public noted;
    address public constant APP_ADMIN = address(0xC0FFEE);

    function admin() external pure returns (address) {
        return APP_ADMIN;
    }

    function upgradeTo(address a) external {
        noted = a;
    }

    function changeAdmin(address a) external {
        noted = a;
    }
}

contract ShieldedProxyHiddenTest is ProxyFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenCraftedBurnArgumentsNeverTouchAdmin() public {
        vm.prank(attacker);
        vm.expectRevert(WrappedToken.InsufficientBalance.selector);
        token.burn(uint256(1) << 128);
        vm.prank(attacker);
        token.burn(0);
        vm.prank(attacker);
        (bool ok, ) = address(proxy).call(abi.encodeWithSelector(bytes4(0x42966c68), bytes16(0)));
        ok;
        assertEq(_admin(), proxyAdmin);
        assertEq(_implementation(), address(impl));
    }

    function testHiddenFullTakeoverChainFails() public {
        SweepImpl evil = new SweepImpl();
        vm.startPrank(attacker);
        token.burn(0);
        (bool up, ) = address(proxy).call(abi.encodeWithSelector(IProxyAdmin.upgradeTo.selector, address(evil)));
        (bool sw, ) = address(proxy).call(abi.encodeWithSelector(SweepImpl.sweep.selector, attacker));
        vm.stopPrank();
        assertFalse(up);
        assertFalse(sw);
        assertEq(address(proxy).balance, 10 ether);
        assertEq(attacker.balance, 1 ether);
        vm.prank(alice);
        token.burn(10 ether);
        assertEq(alice.balance, 100 ether);
    }

    function testHiddenUsersReachClashingImplementationFunctions() public {
        ClashingImpl clash = new ClashingImpl();
        vm.prank(proxyAdmin);
        adminView.upgradeTo(address(clash));

        // A user asking for admin() gets the implementation's answer.
        vm.prank(alice);
        assertEq(adminView.admin(), address(0xC0FFEE));
        // A user calling upgradeTo/changeAdmin runs the implementation's functions.
        vm.prank(alice);
        adminView.upgradeTo(address(0x1234));
        assertEq(ClashingImpl(address(proxy)).noted(), address(0x1234));
        vm.prank(attacker);
        adminView.changeAdmin(attacker);
        assertEq(ClashingImpl(address(proxy)).noted(), attacker);

        // The proxy's own admin and implementation are untouched.
        assertEq(_admin(), proxyAdmin);
        assertEq(_implementation(), address(clash));
    }

    function testHiddenAdminHandover() public {
        address next = address(0xAD2);
        vm.prank(proxyAdmin);
        vm.expectRevert(ShieldedProxy.ZeroAddress.selector);
        adminView.changeAdmin(address(0));
        vm.prank(proxyAdmin);
        adminView.changeAdmin(next);
        vm.prank(next);
        assertEq(adminView.admin(), next);
        // The former admin is now an ordinary user: its calls are forwarded.
        vm.prank(proxyAdmin);
        assertEq(token.version(), 1);
        vm.prank(proxyAdmin);
        vm.expectRevert();
        adminView.upgradeTo(address(impl));
        // The new admin is cut off from the implementation.
        vm.prank(next);
        vm.expectRevert(ShieldedProxy.AdminCannotFallback.selector);
        token.version();
    }

    function testHiddenUpgradeTargetMustBeAContract() public {
        vm.prank(proxyAdmin);
        vm.expectRevert(ShieldedProxy.NotAContract.selector);
        adminView.upgradeTo(address(0xDEAD));
        assertEq(_implementation(), address(impl));
    }

    function testHiddenAdminPlainEtherAndUnknownSelectorsRevert() public {
        vm.deal(proxyAdmin, 1 ether);
        vm.prank(proxyAdmin);
        (bool ok, ) = address(proxy).call{value: 1 ether}("");
        assertFalse(ok);
        vm.prank(proxyAdmin);
        vm.expectRevert(ShieldedProxy.AdminCannotFallback.selector);
        token.burn(0);
        assertEq(address(proxy).balance, 10 ether);
    }

    function testHiddenUserEtherAndDataAreForwarded() public {
        vm.prank(alice);
        (bool ok, ) = address(proxy).call{value: 2 ether}("");
        assertTrue(ok);
        assertEq(token.balanceOf(alice), 12 ether);
        assertEq(address(proxy).balance, 12 ether);
        vm.prank(alice);
        vm.expectRevert(WrappedToken.InsufficientBalance.selector);
        token.burn(13 ether);
        // implementation() is not a token function, so for a user it reverts in the implementation.
        vm.prank(alice);
        vm.expectRevert();
        adminView.implementation();
    }
}

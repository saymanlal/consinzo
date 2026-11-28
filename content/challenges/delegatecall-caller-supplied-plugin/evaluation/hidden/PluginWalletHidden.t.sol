// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PluginWallet.sol";

contract SweepPlugin {
    function sweep(address payable to) external {
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok, "SWEEP");
    }

    function approveSelf(address plugin) external {
        // Tries to flip approvedPlugin[plugin] (mapping at slot 1) from inside the wallet.
        bytes32 slot = keccak256(abi.encode(plugin, uint256(1)));
        assembly {
            sstore(slot, 1)
        }
    }
}

contract EchoPlugin {
    function echo(uint256 x) external pure returns (uint256) {
        return x * 2;
    }

    function fail() external pure {
        revert("NOPE");
    }
}

/// Performs the whole attack in one transaction and swallows failures.
contract Raider {
    receive() external payable {}

    function raid(PluginWallet wallet, SweepPlugin evil, address approved) external {
        try wallet.run(address(evil), abi.encodeWithSelector(SweepPlugin.sweep.selector, payable(address(this)))) {} catch {}
        try wallet.run(address(evil), abi.encodeWithSelector(SweepPlugin.approveSelf.selector, address(evil))) {} catch {}
        address payable[] memory to = new address payable[](1);
        uint256[] memory amounts = new uint256[](1);
        to[0] = payable(address(this));
        amounts[0] = address(wallet).balance;
        try wallet.run(approved, abi.encodeWithSelector(BatchPayPlugin.pay.selector, to, amounts)) {} catch {}
    }
}

contract PluginWalletHiddenTest is Test {
    PluginWallet public wallet;
    BatchPayPlugin public batchPay;
    EchoPlugin public echo;
    address public attacker = address(0xBAD);
    address public alice = address(0xA11CE);

    function setUp() public {
        wallet = new PluginWallet{value: 10 ether}();
        batchPay = new BatchPayPlugin();
        echo = new EchoPlugin();
        wallet.setPlugin(address(batchPay), true);
        wallet.setPlugin(address(echo), true);
    }

    function testHiddenOneTransactionRaidFails() public {
        Raider raider = new Raider();
        SweepPlugin evil = new SweepPlugin();
        raider.raid(wallet, evil, address(batchPay));
        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(raider).balance, 0);
        assertFalse(wallet.approvedPlugin(address(evil)));
        assertEq(wallet.owner(), address(this));
    }

    function testHiddenRevokedPluginStopsWorking() public {
        wallet.setPlugin(address(batchPay), false);
        address payable[] memory to = new address payable[](1);
        uint256[] memory amounts = new uint256[](1);
        to[0] = payable(alice);
        amounts[0] = 1 ether;
        vm.expectRevert(PluginWallet.PluginNotApproved.selector);
        wallet.run(address(batchPay), abi.encodeWithSelector(BatchPayPlugin.pay.selector, to, amounts));
        assertEq(alice.balance, 0);
    }

    function testHiddenReturnDataIsForwarded() public {
        bytes memory ret = wallet.run(address(echo), abi.encodeWithSelector(EchoPlugin.echo.selector, uint256(21)));
        assertEq(abi.decode(ret, (uint256)), 42);
    }

    function testHiddenPluginFailureReverts() public {
        vm.expectRevert(PluginWallet.PluginFailed.selector);
        wallet.run(address(echo), abi.encodeWithSelector(EchoPlugin.fail.selector));
    }

    function testHiddenNewOwnerInheritsControl() public {
        wallet.transferOwnership(alice);
        bytes memory data = abi.encodeWithSelector(EchoPlugin.echo.selector, uint256(1));

        vm.expectRevert(PluginWallet.NotOwner.selector);
        wallet.run(address(echo), data);

        vm.prank(alice);
        wallet.run(address(echo), data);

        vm.expectRevert(PluginWallet.NotOwner.selector);
        wallet.setPlugin(address(echo), false);
    }

    function testHiddenPluginAdministration() public {
        SweepPlugin p = new SweepPlugin();
        vm.expectRevert(PluginWallet.NotOwner.selector);
        vm.prank(attacker);
        wallet.setPlugin(address(p), true);
        assertFalse(wallet.approvedPlugin(address(p)));

        vm.expectRevert(PluginWallet.NotAContract.selector);
        wallet.setPlugin(address(0x1234), true);

        // An address without code must not be runnable even by the owner.
        vm.expectRevert(PluginWallet.PluginNotApproved.selector);
        wallet.run(address(0x1234), hex"deadbeef");
    }
}

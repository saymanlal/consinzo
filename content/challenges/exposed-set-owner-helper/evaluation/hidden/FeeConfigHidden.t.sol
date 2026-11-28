// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeConfig.sol";

contract Hijacker {
    function hijack(FeeConfig config) external returns (bool tookOver) {
        (bool ok, ) = address(config).call(abi.encodeWithSignature("_setOwner(address)", address(this)));
        if (!ok) return false;
        (ok, ) = address(config).call(abi.encodeCall(FeeConfig.setFee, (1_000)));
        return ok;
    }
}

contract FeeConfigHiddenTest is Test {
    FeeConfig public config;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public mallory = address(0xBAD);

    function setUp() public {
        config = new FeeConfig();
        config.setFee(100);
    }

    function testHiddenContractCannotHijack() public {
        Hijacker hijacker = new Hijacker();
        assertFalse(hijacker.hijack(config));
        assertEq(config.owner(), address(this));
        assertEq(config.feeBps(), 100);
    }

    function testHiddenHelperCannotAssignThirdParty() public {
        // Trying to hand ownership to an accomplice instead of to the caller.
        vm.prank(mallory);
        (bool ok, ) = address(config).call(abi.encodeWithSignature("_setOwner(address)", bob));
        assertFalse(ok);
        assertEq(config.owner(), address(this));
    }

    function testHiddenStrangerCannotTransferOwnership() public {
        vm.prank(mallory);
        vm.expectRevert(FeeConfig.NotOwner.selector);
        config.transferOwnership(mallory);
        assertEq(config.owner(), address(this));
    }

    function testHiddenOldOwnerLosesRights() public {
        config.transferOwnership(alice);

        vm.expectRevert(FeeConfig.NotOwner.selector);
        config.setFee(5);
        vm.expectRevert(FeeConfig.NotOwner.selector);
        config.transferOwnership(address(this));

        vm.prank(alice);
        config.transferOwnership(bob);
        assertEq(config.owner(), bob);
        assertEq(config.feeBps(), 100);
    }

    function testHiddenZeroAddressOwnerRejected() public {
        vm.expectRevert(FeeConfig.ZeroAddress.selector);
        config.transferOwnership(address(0));
        assertEq(config.owner(), address(this));
    }

    function testHiddenFeeCapBoundary() public {
        config.setFee(1_000);
        assertEq(config.feeBps(), 1_000);
        vm.expectRevert(FeeConfig.FeeTooHigh.selector);
        config.setFee(1_001);
        assertEq(config.feeBps(), 1_000);
    }
}

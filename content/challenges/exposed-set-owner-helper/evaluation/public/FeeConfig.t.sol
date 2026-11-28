// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeConfig.sol";

contract FeeConfigTest is Test {
    FeeConfig public config;
    address public alice = address(0xA11CE);
    address public mallory = address(0xBAD);

    function setUp() public {
        config = new FeeConfig();
    }

    function testOwnerSetsFee() public {
        assertEq(config.owner(), address(this));
        config.setFee(250);
        assertEq(config.feeBps(), 250);
    }

    function testOwnerTransfersOwnership() public {
        config.transferOwnership(alice);
        assertEq(config.owner(), alice);

        vm.prank(alice);
        config.setFee(30);
        assertEq(config.feeBps(), 30);
    }

    function testStrangerCannotCallHelperDirectly() public {
        vm.prank(mallory);
        (bool ok, ) = address(config).call(abi.encodeWithSignature("_setOwner(address)", mallory));
        assertFalse(ok, "direct _setOwner call must fail");
        assertEq(config.owner(), address(this));
    }

    function testStrangerCannotSetFee() public {
        vm.prank(mallory);
        vm.expectRevert(FeeConfig.NotOwner.selector);
        config.setFee(1_000);
        assertEq(config.feeBps(), 0);
    }
}

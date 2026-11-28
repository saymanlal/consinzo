// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeConfig.sol";

contract FeeConfigTest is Test {
    FeeConfig public config;
    address public treasury = address(0x7EA5);

    function setUp() public {
        vm.warp(1_800_000_000);
        config = new FeeConfig(treasury, 250);
    }

    function testConstants() public {
        assertEq(config.BPS_DENOMINATOR(), 10_000);
        assertEq(config.MAX_FEE_BPS(), 1_000);
        assertEq(config.LOCK_PERIOD(), 7 days);
    }

    function testStoresConfiguration() public {
        assertEq(config.treasury(), treasury);
        assertEq(config.feeBps(), 250);
        assertEq(config.deployedAt(), 1_800_000_000);
    }

    function testFeeAndNetAmount() public {
        assertEq(config.feeFor(1 ether), 0.025 ether);
        assertEq(config.netAmount(1 ether), 0.975 ether);
        assertEq(config.feeFor(0), 0);
    }

    function testUnlockTime() public {
        assertEq(config.unlockTime(), 1_800_000_000 + 7 days);
        assertFalse(config.isUnlocked());
        vm.warp(1_800_000_000 + 7 days);
        assertTrue(config.isUnlocked());
    }

    function testRejectsZeroTreasury() public {
        try new FeeConfig(address(0), 250) returns (FeeConfig) {
            assertTrue(false, "zero treasury accepted");
        } catch (bytes memory reason) {
            assertEq(bytes32(reason), bytes32(FeeConfig.ZeroTreasury.selector));
        }
    }

    function testRejectsFeeAboveMaximum() public {
        try new FeeConfig(treasury, 1_001) returns (FeeConfig) {
            assertTrue(false, "excessive fee accepted");
        } catch (bytes memory reason) {
            assertEq(
                keccak256(reason),
                keccak256(abi.encodeWithSelector(FeeConfig.FeeTooHigh.selector, 1_001, 1_000))
            );
        }
    }
}

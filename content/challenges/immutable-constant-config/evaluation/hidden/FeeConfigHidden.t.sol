// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FeeConfig.sol";

contract FeeConfigHiddenTest is Test {
    address public treasury = address(0xBEEF);

    function testHiddenMaximumFeeIsAccepted() public {
        FeeConfig config = new FeeConfig(treasury, 1_000);
        assertEq(config.feeBps(), 1_000);
        assertEq(config.feeFor(12_345), 1_234);
        assertEq(config.netAmount(12_345), 11_111);
    }

    function testHiddenZeroFeeIsAccepted() public {
        FeeConfig config = new FeeConfig(treasury, 0);
        assertEq(config.feeBps(), 0);
        assertEq(config.feeFor(5 ether), 0);
        assertEq(config.netAmount(5 ether), 5 ether);
    }

    function testHiddenFeeRoundsDown() public {
        FeeConfig config = new FeeConfig(treasury, 1);
        assertEq(config.feeFor(9_999), 0);
        assertEq(config.netAmount(9_999), 9_999);
        assertEq(config.feeFor(10_000), 1);
        assertEq(config.feeFor(19_999), 1);
        assertEq(config.feeFor(20_000), 2);
    }

    function testHiddenMultipliesBeforeDividing() public {
        FeeConfig config = new FeeConfig(treasury, 333);
        // 4_999 * 333 / 10_000 = 166 (dividing first would give 0)
        assertEq(config.feeFor(4_999), 166);
        assertEq(config.netAmount(4_999), 4_833);
    }

    function testHiddenFeePlusNetEqualsAmount() public {
        FeeConfig config = new FeeConfig(treasury, 777);
        uint256[5] memory amounts = [uint256(1), 13, 10_001, 3 ether + 7, type(uint128).max];
        for (uint256 i = 0; i < amounts.length; i++) {
            assertEq(config.feeFor(amounts[i]) + config.netAmount(amounts[i]), amounts[i]);
        }
        assertEq(config.feeFor(type(uint128).max), (uint256(type(uint128).max) * 777) / 10_000);
    }

    function testHiddenFeeErrorCarriesBothValues() public {
        try new FeeConfig(treasury, 54_321) returns (FeeConfig) {
            assertTrue(false, "excessive fee accepted");
        } catch (bytes memory reason) {
            assertEq(
                keccak256(reason),
                keccak256(abi.encodeWithSelector(FeeConfig.FeeTooHigh.selector, 54_321, 1_000))
            );
        }
    }

    function testHiddenTreasuryCheckedBeforeFee() public {
        try new FeeConfig(address(0), 9_999) returns (FeeConfig) {
            assertTrue(false, "invalid configuration accepted");
        } catch (bytes memory reason) {
            assertEq(reason.length, 4);
            assertEq(bytes32(reason), bytes32(FeeConfig.ZeroTreasury.selector));
        }
    }

    function testHiddenDeployedAtFollowsBlockTime() public {
        vm.warp(2_000_000_123);
        FeeConfig config = new FeeConfig(treasury, 10);
        assertEq(config.deployedAt(), 2_000_000_123);
        assertEq(config.unlockTime(), 2_000_000_123 + 7 days);

        vm.warp(2_000_000_123 + 7 days - 1);
        assertFalse(config.isUnlocked());
        vm.warp(2_000_000_123 + 7 days);
        assertTrue(config.isUnlocked());
        vm.warp(2_000_000_123 + 30 days);
        assertTrue(config.isUnlocked());
        // The stored values never move with time.
        assertEq(config.deployedAt(), 2_000_000_123);
        assertEq(config.treasury(), treasury);
    }
}

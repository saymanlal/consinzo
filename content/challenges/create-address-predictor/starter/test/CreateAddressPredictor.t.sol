// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CreateAddressPredictor.sol";

contract Marker {
    uint256 public immutable id;

    constructor(uint256 id_) {
        id = id_;
    }
}

/// Deploys contracts with CREATE. A new contract starts with nonce 1 (EIP-161).
contract Spawner {
    uint256 public deployments;

    function spawn() external returns (address created) {
        created = address(new Marker(deployments));
        deployments += 1;
    }
}

contract CreateAddressPredictorTest is Test {
    CreateAddressPredictor public predictor;
    Spawner public spawner;

    function setUp() public {
        predictor = new CreateAddressPredictor();
        spawner = new Spawner();
    }

    function testEncodeSmallNonces() public view {
        assertEq(keccak256(predictor.encodeNonce(0)), keccak256(hex"80"));
        assertEq(keccak256(predictor.encodeNonce(1)), keccak256(hex"01"));
        assertEq(keccak256(predictor.encodeNonce(0x7f)), keccak256(hex"7f"));
        assertEq(keccak256(predictor.encodeNonce(0x80)), keccak256(hex"8180"));
        assertEq(keccak256(predictor.encodeNonce(0x0400)), keccak256(hex"820400"));
    }

    function testEncodeDeployerAndNonce() public view {
        address deployer = 0x00112233445566778899AABbCCdDeeFf00112233;
        assertEq(
            keccak256(predictor.encodeDeployerAndNonce(deployer, 1)),
            keccak256(hex"d69400112233445566778899aabbccddeeff0011223301")
        );
        assertEq(
            keccak256(predictor.encodeDeployerAndNonce(deployer, 0x80)),
            keccak256(hex"d79400112233445566778899aabbccddeeff001122338180")
        );
    }

    function testMatchesRealDeployments() public {
        for (uint256 nonce = 1; nonce <= 5; nonce++) {
            address predicted = predictor.computeAddress(address(spawner), nonce);
            address created = spawner.spawn();
            assertEq(created, predicted);
            assertGt(created.code.length, 0);
        }
    }

    function testKnownVectorNonceZero() public view {
        assertEq(
            predictor.computeAddress(address(uint160(0xdeadbeef)), 0),
            0xE8279BE14E9fe2Ad2D8E52E42Ca96Fb33a813BBe
        );
    }
}

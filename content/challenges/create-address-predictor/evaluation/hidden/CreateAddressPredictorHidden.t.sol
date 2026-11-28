// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CreateAddressPredictor.sol";

/// Deploys empty contracts as cheaply as possible so that many nonces can be consumed.
contract CheapSpawner {
    function spawn() public returns (address created) {
        // Init code is a single STOP: the deployment succeeds with empty runtime code.
        bytes memory initCode = hex"00";
        assembly {
            created := create(0, add(initCode, 0x20), 1)
        }
        require(created != address(0), "create failed");
    }
}

contract SpawnerFactory {
    function spawnChildSpawner() external returns (CheapSpawner) {
        return new CheapSpawner();
    }
}

contract CreateAddressPredictorHiddenTest is Test {
    CreateAddressPredictor public predictor;
    CheapSpawner public spawner;
    address internal constant DEPLOYER = address(uint160(0xdeadbeef));

    function setUp() public {
        predictor = new CreateAddressPredictor();
        spawner = new CheapSpawner();
    }

    function testHiddenRealDeploymentsAcrossOneByteBoundary() public {
        // Nonces 1..135 cross the 0x7f -> 0x80 boundary where the encoding gains a prefix.
        for (uint256 nonce = 1; nonce <= 135; nonce++) {
            address created = spawner.spawn();
            assertEq(created, predictor.computeAddress(address(spawner), nonce));
        }
    }

    function testHiddenNestedDeployerStartsAtNonceOne() public {
        // The factory's nonce 1 creates the child; the child's own first creation uses nonce 1.
        SpawnerFactory factory = new SpawnerFactory();
        CheapSpawner child = factory.spawnChildSpawner();
        assertEq(address(child), predictor.computeAddress(address(factory), 1));
        address grandChild = child.spawn();
        assertEq(grandChild, predictor.computeAddress(address(child), 1));
        assertNotEq(grandChild, predictor.computeAddress(address(child), 0));
    }

    function testHiddenKnownVectors() public view {
        assertEq(predictor.computeAddress(DEPLOYER, 1), 0xa97d2bE8AfCFCfF4b5726FE707ccc6785Ac4D51c);
        assertEq(predictor.computeAddress(DEPLOYER, 127), 0x391D2c0b0bee69B978da3f9a93C7aA9d3cdB413A);
        assertEq(predictor.computeAddress(DEPLOYER, 128), 0xf79aa76fA2712826Af19CF0246c42D5f27e5EE2a);
        assertEq(predictor.computeAddress(DEPLOYER, 255), 0x81EBD3f4231c998864dE607F12A747284343F999);
        assertEq(predictor.computeAddress(DEPLOYER, 256), 0xe86b23AAAAC049445fcCF25aCF493BAA95001331);
        assertEq(predictor.computeAddress(DEPLOYER, 65535), 0xf0Aa5b0c4E1f58a056a7d19253340056781a53a6);
        assertEq(predictor.computeAddress(DEPLOYER, 65536), 0x2d2B5D60Af91BEeFd26e136D4141Fc8dFE2cA53b);
        assertEq(predictor.computeAddress(DEPLOYER, 16777216), 0xe2930c73F7139112b0D1744C31acF9806681E9F4);
        assertEq(predictor.computeAddress(DEPLOYER, 4294967296), 0xB7180274CAf2017E301eF1640B271c95D81658C6);
    }

    function testHiddenMaximumNonce() public view {
        assertEq(
            predictor.computeAddress(DEPLOYER, type(uint64).max),
            0x4C6c7bb86Ce297680A8e5540E2edA341ffCa9070
        );
        assertEq(
            predictor.computeAddress(DEPLOYER, uint256(type(uint64).max) - 1),
            0xbC773Ad91D1669416aE48955F0ff3ECae94cE19b
        );
        assertEq(keccak256(predictor.encodeNonce(type(uint64).max)), keccak256(hex"88ffffffffffffffff"));
        assertEq(
            keccak256(predictor.encodeDeployerAndNonce(DEPLOYER, type(uint64).max)),
            keccak256(hex"de9400000000000000000000000000000000deadbeef88ffffffffffffffff")
        );
    }

    function testHiddenEncodeNonceBoundaries() public view {
        assertEq(keccak256(predictor.encodeNonce(0xff)), keccak256(hex"81ff"));
        assertEq(keccak256(predictor.encodeNonce(0x100)), keccak256(hex"820100"));
        assertEq(keccak256(predictor.encodeNonce(0xffff)), keccak256(hex"82ffff"));
        assertEq(keccak256(predictor.encodeNonce(0x010000)), keccak256(hex"83010000"));
        assertEq(keccak256(predictor.encodeNonce(0x0100000000)), keccak256(hex"850100000000"));
        assertEq(keccak256(predictor.encodeNonce(0x00ab00cd00ef00)), keccak256(hex"86ab00cd00ef00"));
        assertEq(predictor.encodeNonce(0).length, 1);
        assertEq(predictor.encodeNonce(0x7f).length, 1);
    }

    function testHiddenNonceTooHighReverts() public {
        uint256 tooHigh = uint256(type(uint64).max) + 1;
        vm.expectRevert(abi.encodeWithSelector(CreateAddressPredictor.NonceTooHigh.selector, tooHigh));
        predictor.computeAddress(DEPLOYER, tooHigh);

        vm.expectRevert(abi.encodeWithSelector(CreateAddressPredictor.NonceTooHigh.selector, type(uint256).max));
        predictor.encodeNonce(type(uint256).max);

        vm.expectRevert(CreateAddressPredictor.NonceTooHigh.selector);
        predictor.encodeDeployerAndNonce(DEPLOYER, tooHigh);
    }

    function testHiddenAddressWithLeadingZeroBytesKeepsTwentyBytes() public view {
        // The address is always encoded as 20 bytes, never trimmed.
        assertEq(
            keccak256(predictor.encodeDeployerAndNonce(address(0), 0)),
            keccak256(hex"d694000000000000000000000000000000000000000080")
        );
        assertEq(
            predictor.computeAddress(address(0), 0),
            address(uint160(uint256(keccak256(hex"d694000000000000000000000000000000000000000080"))))
        );
    }
}

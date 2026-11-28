// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Create3Deployer.sol";

contract Greeter {
    string public greeting;
    address public creator;

    constructor(string memory greeting_) payable {
        greeting = greeting_;
        creator = msg.sender;
    }
}

contract Tiny {
    uint256 public constant ID = 7;
}

contract Create3DeployerTest is Test {
    error Probe(address deployed, uint256 codeLength);

    Create3Deployer public deployer;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    bytes32 internal constant SALT = keccak256("salt-1");

    function setUp() public {
        deployer = new Create3Deployer();
    }

    function _greeterCode(string memory greeting) internal pure returns (bytes memory) {
        return abi.encodePacked(type(Greeter).creationCode, abi.encode(greeting));
    }

    /// Deploys and then reverts, reporting what happened. Lets a test try the same salt twice.
    function deployThenRevert(bytes32 salt, bytes memory initCode) external {
        address deployed = deployer.deploy(salt, initCode);
        revert Probe(deployed, deployed.code.length);
    }

    function testDeployAtPredictedAddress() public {
        address predicted = deployer.addressOf(address(this), SALT);
        assertEq(predicted.code.length, 0);

        address deployed = deployer.deploy(SALT, _greeterCode("hello"));
        assertEq(deployed, predicted);
        assertGt(deployed.code.length, 0);
        assertEq(Greeter(deployed).greeting(), "hello");
    }

    function testAddressIsIndependentOfInitCode() public {
        // First attempt with one contract, rolled back.
        address first;
        try this.deployThenRevert(SALT, type(Tiny).creationCode) {
            assertTrue(false, "probe did not revert");
        } catch (bytes memory err) {
            assertEq(bytes4(err), Probe.selector);
            uint256 codeLength;
            assembly {
                first := mload(add(err, 0x24))
                codeLength := mload(add(err, 0x44))
            }
            assertGt(codeLength, 0);
        }

        // Second attempt with completely different init code and the same salt.
        address second = deployer.deploy(SALT, _greeterCode("different code"));
        assertEq(second, first);
        assertEq(second, deployer.addressOf(address(this), SALT));
    }

    function testDifferentCallersGetDifferentAddresses() public {
        assertNotEq(deployer.addressOf(alice, SALT), deployer.addressOf(bob, SALT));

        vm.prank(alice);
        address a = deployer.deploy(SALT, type(Tiny).creationCode);
        vm.prank(bob);
        address b = deployer.deploy(SALT, type(Tiny).creationCode);

        assertEq(a, deployer.addressOf(alice, SALT));
        assertEq(b, deployer.addressOf(bob, SALT));
        assertNotEq(a, b);
    }

    function testSaltCannotBeReused() public {
        deployer.deploy(SALT, type(Tiny).creationCode);
        vm.expectRevert(Create3Deployer.ProxyDeploymentFailed.selector);
        deployer.deploy(SALT, _greeterCode("again"));
    }
}

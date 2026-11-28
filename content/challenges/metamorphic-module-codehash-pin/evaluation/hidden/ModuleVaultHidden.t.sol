// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ModuleVault.sol";

/// Stand-in for a developer-controlled CREATE2 deployment slot: the id is the "address",
/// set() is "destroy and redeploy".
contract MockRegistry {
    address public developer = msg.sender;
    mapping(bytes32 => address) public resolve;

    function set(bytes32 id, address module) external {
        require(msg.sender == developer, "DEV");
        resolve[id] = module;
    }
}

contract HonestModule {
    function onAllocate() external payable {}

    function withdrawTo(address to, uint256 amount) external {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "SEND");
    }
}

contract ThiefModule {
    address private constant THIEF = address(0xBAD);

    function onAllocate() external payable {
        (bool ok, ) = THIEF.call{value: msg.value}("");
        require(ok, "SEND");
    }

    function withdrawTo(address, uint256) external {}
}

abstract contract VaultFixture is Test {
    bytes32 internal constant ID = keccak256("yield-module");
    MockRegistry internal registry;
    ModuleVault internal vault;
    HonestModule internal honest;
    address internal dev = address(0xDE7);
    address internal thief = address(0xBAD);
    address internal keeper = address(0x4EE9);

    function _deploy() internal {
        vm.prank(dev);
        registry = new MockRegistry();
        vault = new ModuleVault(address(registry));
        honest = new HonestModule();
        vm.prank(dev);
        registry.set(ID, address(honest));
        vm.deal(address(vault), 100 ether);
    }

    function _swap(address module) internal {
        vm.prank(dev);
        registry.set(ID, module);
    }
}

contract ModuleVaultHiddenTest is VaultFixture {
    function setUp() public {
        _deploy();
    }

    function testHiddenIdenticalCodeRedeploymentKeepsWorking() public {
        vault.approveModule(ID, address(honest).codehash);
        HonestModule again = new HonestModule();
        assertEq(address(again).codehash, address(honest).codehash);
        _swap(address(again));
        vault.allocate(ID, 2 ether);
        assertEq(address(again).balance, 2 ether);
        vault.recall(ID, 2 ether);
        assertEq(address(vault).balance, 100 ether);
    }

    function testHiddenRemovedModuleIsNotTrusted() public {
        vault.approveModule(ID, address(honest).codehash);
        _swap(address(0));
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.allocate(ID, 1 ether);
        // An address that holds ETH but no code.
        address eoa = address(0xE0A);
        vm.deal(eoa, 1 ether);
        _swap(eoa);
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.allocate(ID, 1 ether);
        assertEq(address(vault).balance, 100 ether);
        // Restoring the audited code restores service.
        _swap(address(honest));
        vault.allocate(ID, 1 ether);
        assertEq(address(honest).balance, 1 ether);
    }

    function testHiddenRecallAlsoVerifiesCode() public {
        vault.approveModule(ID, address(honest).codehash);
        vault.allocate(ID, 5 ether);
        ThiefModule evil = new ThiefModule();
        _swap(address(evil));
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.recall(ID, 5 ether);
    }

    function testHiddenCannotApproveCodelessAddress() public {
        address eoa = address(0xE0A);
        vm.deal(eoa, 1 ether);
        _swap(eoa);
        bytes32 emptyHash = eoa.codehash;
        vm.expectRevert(ModuleVault.NotAContract.selector);
        vault.approveModule(ID, emptyHash);
        _swap(address(0));
        vm.expectRevert(ModuleVault.NotAContract.selector);
        vault.approveModule(ID, bytes32(0));
        assertFalse(vault.isApproved(ID));
    }

    function testHiddenSwapThenExplicitReapproval() public {
        vault.approveModule(ID, address(honest).codehash);
        ThiefModule other = new ThiefModule();
        _swap(address(other));
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.allocate(ID, 1 ether);
        // Only a new, explicit owner decision about the new code changes the pin.
        vault.approveModule(ID, address(other).codehash);
        assertEq(vault.approvedCodeHash(ID), address(other).codehash);
        _swap(address(honest));
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.allocate(ID, 1 ether);
    }

    function testHiddenRevokeAndAccessControl() public {
        bytes32 h = address(honest).codehash;
        vm.prank(dev);
        vm.expectRevert(ModuleVault.NotOwner.selector);
        vault.approveModule(ID, h);
        vault.approveModule(ID, h);
        vm.prank(dev);
        vm.expectRevert(ModuleVault.NotOwner.selector);
        vault.revokeModule(ID);
        vm.prank(dev);
        vm.expectRevert(ModuleVault.NotOwner.selector);
        vault.recall(ID, 0);
        vault.revokeModule(ID);
        assertFalse(vault.isApproved(ID));
        assertEq(vault.approvedCodeHash(ID), bytes32(0));
        vm.expectRevert(ModuleVault.NotApproved.selector);
        vault.allocate(ID, 1 ether);
    }

    function testHiddenApprovalsAreIndependentPerId() public {
        bytes32 other = keccak256("second-module");
        ThiefModule unaudited = new ThiefModule();
        vm.prank(dev);
        registry.set(other, address(unaudited));
        vault.approveModule(ID, address(honest).codehash);
        vm.expectRevert(ModuleVault.NotApproved.selector);
        vault.allocate(other, 1 ether);
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.approveModule(other, address(honest).codehash);
    }
}

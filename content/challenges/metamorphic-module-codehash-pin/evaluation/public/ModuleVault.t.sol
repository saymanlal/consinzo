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

contract ModuleVaultTest is VaultFixture {
    function setUp() public {
        _deploy();
    }

    function testSwappedCodeLosesTheApproval() public {
        vault.approveModule(ID, address(honest).codehash);
        vm.prank(keeper);
        vault.allocate(ID, 1 ether);
        assertEq(address(honest).balance, 1 ether);

        // The developer "destroys and redeploys" different code behind the approved identity.
        ThiefModule evil = new ThiefModule();
        _swap(address(evil));

        vm.prank(keeper);
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.allocate(ID, 99 ether);
        assertEq(address(vault).balance, 99 ether);
        assertEq(thief.balance, 0);
    }

    function testApprovalPinsTheAuditedHash() public {
        bytes32 audited = address(honest).codehash;
        vault.approveModule(ID, audited);
        assertEq(vault.approvedCodeHash(ID), audited);
        assertTrue(vault.isApproved(ID));
    }

    function testApprovalFailsIfCodeChangedSinceAudit() public {
        bytes32 audited = address(honest).codehash;
        ThiefModule evil = new ThiefModule();
        _swap(address(evil)); // front-runs the approval transaction
        vm.expectRevert(ModuleVault.CodeHashMismatch.selector);
        vault.approveModule(ID, audited);
        assertFalse(vault.isApproved(ID));
    }

    function testAllocateAndRecall() public {
        vault.approveModule(ID, address(honest).codehash);
        vault.allocate(ID, 10 ether);
        assertEq(address(vault).balance, 90 ether);
        vault.recall(ID, 4 ether);
        assertEq(address(vault).balance, 94 ether);
        assertEq(address(honest).balance, 6 ether);
    }

    function testUnapprovedModuleRejected() public {
        vm.expectRevert(ModuleVault.NotApproved.selector);
        vault.allocate(ID, 1 ether);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BridgeDepositBox.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public returnFalse;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setReturnFalse(bool value) external {
        returnFalse = value;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (returnFalse) return false;
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract BridgeDepositBoxHiddenTest is Test {
    uint256 internal constant ARBITRUM = 42161;
    uint256 internal constant OPTIMISM = 10;

    MockERC20 public token;
    BridgeDepositBox public box;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        token = new MockERC20();
        box = new BridgeDepositBox(address(token));
        box.setChainSupported(ARBITRUM, true);
        box.setChainSupported(OPTIMISM, true);

        token.mint(alice, 1_000 ether);
        token.mint(bob, 1_000 ether);
        vm.prank(alice);
        token.approve(address(box), type(uint256).max);
        vm.prank(bob);
        token.approve(address(box), type(uint256).max);
    }

    function testHiddenConstructorRejectsZeroToken() public {
        vm.expectRevert(BridgeDepositBox.ZeroAddress.selector);
        new BridgeDepositBox(address(0));
    }

    function testHiddenOnlyOwnerConfiguresChains() public {
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.NotOwner.selector);
        box.setChainSupported(8453, true);
        assertFalse(box.supportedChain(8453));
        assertEq(box.owner(), address(this));
    }

    function testHiddenLocalChainCannotBeDestination() public {
        uint256 local = block.chainid;
        vm.expectRevert(BridgeDepositBox.SameChain.selector);
        box.setChainSupported(local, true);
        assertFalse(box.supportedChain(local));

        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.UnsupportedChain.selector);
        box.deposit(local, bob, 1 ether);
    }

    function testHiddenCheckOrder() public {
        // unsupported chain wins over zero recipient and zero amount
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.UnsupportedChain.selector);
        box.deposit(8453, address(0), 0);

        // zero recipient wins over zero amount
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.ZeroAddress.selector);
        box.deposit(ARBITRUM, address(0), 0);

        assertEq(box.nextNonce(ARBITRUM), 0);
    }

    function testHiddenFalseReturningTokenReverts() public {
        token.setReturnFalse(true);
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.TransferFailed.selector);
        box.deposit(ARBITRUM, bob, 5 ether);

        // nothing was recorded for the failed attempt
        assertEq(box.nextNonce(ARBITRUM), 0);
        assertEq(box.totalLocked(), 0);
        assertEq(box.lockedFor(ARBITRUM), 0);

        token.setReturnFalse(false);
        vm.prank(alice);
        assertEq(box.deposit(ARBITRUM, bob, 5 ether), 0);
    }

    function testHiddenDepositWithoutAllowanceReverts() public {
        address carol = address(0xCA201);
        token.mint(carol, 10 ether);
        vm.prank(carol);
        vm.expectRevert();
        box.deposit(ARBITRUM, carol, 1 ether);
        assertEq(box.nextNonce(ARBITRUM), 0);
    }

    function testHiddenAccountingAcrossChainsAndUsers() public {
        vm.prank(alice);
        box.deposit(ARBITRUM, alice, 10 ether);
        vm.prank(bob);
        box.deposit(OPTIMISM, alice, 20 ether);
        vm.prank(bob);
        box.deposit(ARBITRUM, bob, 30 ether);

        assertEq(box.lockedFor(ARBITRUM), 40 ether);
        assertEq(box.lockedFor(OPTIMISM), 20 ether);
        assertEq(box.totalLocked(), 60 ether);
        assertEq(token.balanceOf(address(box)), 60 ether);

        (address d0,, uint256 a0) = box.deposits(ARBITRUM, 0);
        (address d1, address r1, uint256 a1) = box.deposits(ARBITRUM, 1);
        (address o0, address or0, uint256 oa0) = box.deposits(OPTIMISM, 0);
        assertEq(d0, alice);
        assertEq(a0, 10 ether);
        assertEq(d1, bob);
        assertEq(r1, bob);
        assertEq(a1, 30 ether);
        assertEq(o0, bob);
        assertEq(or0, alice);
        assertEq(oa0, 20 ether);
    }

    function testHiddenDisablingKeepsNonceAndRecords() public {
        vm.prank(alice);
        box.deposit(ARBITRUM, bob, 1 ether);
        vm.prank(alice);
        box.deposit(ARBITRUM, bob, 2 ether);

        box.setChainSupported(ARBITRUM, false);
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.UnsupportedChain.selector);
        box.deposit(ARBITRUM, bob, 3 ether);

        box.setChainSupported(ARBITRUM, true);
        vm.prank(alice);
        assertEq(box.deposit(ARBITRUM, bob, 3 ether), 2); // continues, never reuses 0 or 1

        (,, uint256 amount1) = box.deposits(ARBITRUM, 1);
        assertEq(amount1, 2 ether);
        assertEq(box.lockedFor(ARBITRUM), 6 ether);
    }

    function testHiddenDepositHashUnknownNonce() public {
        vm.expectRevert(BridgeDepositBox.UnknownDeposit.selector);
        box.depositHash(ARBITRUM, 0);

        vm.prank(alice);
        box.deposit(ARBITRUM, bob, 1 ether);
        box.depositHash(ARBITRUM, 0);

        vm.expectRevert(BridgeDepositBox.UnknownDeposit.selector);
        box.depositHash(ARBITRUM, 1);
        vm.expectRevert(BridgeDepositBox.UnknownDeposit.selector);
        box.depositHash(OPTIMISM, 0); // same nonce, other destination: not used
    }

    function testHiddenDepositHashesAreUnique() public {
        // identical depositor, recipient and amount everywhere
        vm.startPrank(alice);
        box.deposit(ARBITRUM, bob, 1 ether);
        box.deposit(ARBITRUM, bob, 1 ether);
        box.deposit(OPTIMISM, bob, 1 ether);
        vm.stopPrank();

        bytes32 a0 = box.depositHash(ARBITRUM, 0);
        bytes32 a1 = box.depositHash(ARBITRUM, 1);
        bytes32 o0 = box.depositHash(OPTIMISM, 0);
        assertTrue(a0 != a1);
        assertTrue(a0 != o0);
        assertTrue(a1 != o0);

        assertEq(a1, keccak256(abi.encode(block.chainid, address(box), ARBITRUM, uint256(1), alice, bob, uint256(1 ether))));

        // a second box with the same deposit yields a different identifier
        BridgeDepositBox other = new BridgeDepositBox(address(token));
        other.setChainSupported(ARBITRUM, true);
        vm.prank(alice);
        token.approve(address(other), 1 ether);
        vm.prank(alice);
        other.deposit(ARBITRUM, bob, 1 ether);
        assertTrue(other.depositHash(ARBITRUM, 0) != a0);
    }
}

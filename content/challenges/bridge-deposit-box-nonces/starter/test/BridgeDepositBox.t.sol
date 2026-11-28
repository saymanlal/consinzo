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

contract BridgeDepositBoxTest is Test {
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

    function testDepositLocksTokensAndRecords() public {
        vm.prank(alice);
        uint256 nonce = box.deposit(ARBITRUM, bob, 100 ether);

        assertEq(nonce, 0);
        assertEq(token.balanceOf(address(box)), 100 ether);
        assertEq(token.balanceOf(alice), 900 ether);
        (address depositor, address recipient, uint256 amount) = box.deposits(ARBITRUM, 0);
        assertEq(depositor, alice);
        assertEq(recipient, bob);
        assertEq(amount, 100 ether);
        assertEq(box.totalLocked(), 100 ether);
        assertEq(box.lockedFor(ARBITRUM), 100 ether);
    }

    function testNoncesAreSequentialPerDestination() public {
        vm.startPrank(alice);
        assertEq(box.deposit(ARBITRUM, alice, 1 ether), 0);
        assertEq(box.deposit(ARBITRUM, alice, 1 ether), 1);
        assertEq(box.deposit(OPTIMISM, alice, 1 ether), 0);
        assertEq(box.deposit(ARBITRUM, alice, 1 ether), 2);
        vm.stopPrank();

        assertEq(box.nextNonce(ARBITRUM), 3);
        assertEq(box.nextNonce(OPTIMISM), 1);
    }

    function testUnsupportedChainReverts() public {
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.UnsupportedChain.selector);
        box.deposit(8453, bob, 1 ether);
    }

    function testZeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(BridgeDepositBox.ZeroAmount.selector);
        box.deposit(ARBITRUM, bob, 0);
    }

    function testDepositHashMatchesFormula() public {
        vm.prank(alice);
        box.deposit(OPTIMISM, bob, 7 ether);
        bytes32 expected =
            keccak256(abi.encode(block.chainid, address(box), OPTIMISM, uint256(0), alice, bob, uint256(7 ether)));
        assertEq(box.depositHash(OPTIMISM, 0), expected);
    }
}

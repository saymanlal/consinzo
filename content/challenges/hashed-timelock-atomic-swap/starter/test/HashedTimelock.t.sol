// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/HashedTimelock.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract HashedTimelockTest is Test {
    HashedTimelock public chainA;
    HashedTimelock public chainB;
    MockERC20 public tokenA;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public anyone = address(0xD00D);

    bytes32 internal constant SECRET = keccak256("alice secret");
    bytes32 internal hashlock;
    uint64 internal t0;

    function setUp() public {
        chainA = new HashedTimelock();
        chainB = new HashedTimelock();
        tokenA = new MockERC20();
        hashlock = sha256(abi.encodePacked(SECRET));
        t0 = uint64(block.timestamp);

        tokenA.mint(alice, 1_000 ether);
        vm.prank(alice);
        tokenA.approve(address(chainA), type(uint256).max);
        vm.deal(bob, 10 ether);
    }

    function testLockEthStoresSwap() public {
        vm.prank(bob);
        bytes32 id = chainB.lockETH{value: 1 ether}(alice, hashlock, t0 + 1 hours);

        assertEq(id, chainB.computeSwapId(bob, alice, address(0), 1 ether, hashlock, t0 + 1 hours));
        (address sender, address recipient, address token, uint256 amount, bytes32 h, uint64 timelock, HashedTimelock.State state) =
            chainB.swaps(id);
        assertEq(sender, bob);
        assertEq(recipient, alice);
        assertEq(token, address(0));
        assertEq(amount, 1 ether);
        assertEq(h, hashlock);
        assertEq(uint256(timelock), uint256(t0) + 1 hours);
        assertEq(uint256(state), uint256(HashedTimelock.State.Open));
        assertEq(address(chainB).balance, 1 ether);
    }

    function testClaimWithPreimagePaysRecipient() public {
        vm.prank(bob);
        bytes32 id = chainB.lockETH{value: 1 ether}(alice, hashlock, t0 + 1 hours);

        vm.prank(anyone); // anyone may submit the claim; funds still go to the recipient
        chainB.claim(id, SECRET);

        assertEq(alice.balance, 1 ether);
        assertEq(anyone.balance, 0);
        assertEq(chainB.preimageOf(id), SECRET);
        (,,,,,, HashedTimelock.State state) = chainB.swaps(id);
        assertEq(uint256(state), uint256(HashedTimelock.State.Claimed));
    }

    function testWrongPreimageRejected() public {
        vm.prank(bob);
        bytes32 id = chainB.lockETH{value: 1 ether}(alice, hashlock, t0 + 1 hours);
        vm.expectRevert(HashedTimelock.InvalidPreimage.selector);
        chainB.claim(id, keccak256("guess"));
    }

    function testRefundOnlyAfterExpiry() public {
        vm.prank(alice);
        bytes32 id = chainA.lockToken(address(tokenA), 100 ether, bob, hashlock, t0 + 2 hours);
        assertEq(tokenA.balanceOf(address(chainA)), 100 ether);

        vm.expectRevert(HashedTimelock.NotExpired.selector);
        chainA.refund(id);

        vm.warp(t0 + 2 hours);
        chainA.refund(id);
        assertEq(tokenA.balanceOf(alice), 1_000 ether);
        assertEq(tokenA.balanceOf(address(chainA)), 0);

        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        chainA.refund(id);
    }

    function testAtomicSwapAcrossTwoChains() public {
        // Alice (holder of the secret) locks tokens for Bob on chain A with the long timeout.
        vm.prank(alice);
        bytes32 idA = chainA.lockToken(address(tokenA), 100 ether, bob, hashlock, t0 + 2 hours);
        // Bob locks ETH for Alice on chain B with the short timeout.
        vm.prank(bob);
        bytes32 idB = chainB.lockETH{value: 1 ether}(alice, hashlock, t0 + 1 hours);

        // Alice claims on chain B, which publishes the secret there.
        vm.warp(t0 + 30 minutes);
        vm.prank(alice);
        chainB.claim(idB, SECRET);

        // Bob reads the secret from chain B and uses it on chain A.
        bytes32 revealed = chainB.preimageOf(idB);
        vm.prank(bob);
        chainA.claim(idA, revealed);

        assertEq(alice.balance, 1 ether);
        assertEq(tokenA.balanceOf(bob), 100 ether);
        assertEq(tokenA.balanceOf(address(chainA)), 0);
        assertEq(address(chainB).balance, 0);
    }
}

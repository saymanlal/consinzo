// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AttestedBridge.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    bool public returnFalse;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setReturnFalse(bool value) external {
        returnFalse = value;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (returnFalse) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract AttestedBridgeTest is Test {
    uint256 internal constant SRC = 42161;

    MockERC20 public token;
    AttestedBridge public bridge;
    address public r1 = address(0x1001);
    address public r2 = address(0x1002);
    address public r3 = address(0x1003);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        address[] memory rs = new address[](3);
        rs[0] = r1;
        rs[1] = r2;
        rs[2] = r3;
        bridge = new AttestedBridge(rs, 2);
        token = new MockERC20();
        token.mint(address(bridge), 10_000 ether);
        bridge.setRateLimit(address(token), 1_000 ether);
    }

    function _attest(address relayer, uint256 nonce, address to, uint256 amount) internal {
        vm.prank(relayer);
        bridge.attest(SRC, nonce, address(token), to, amount);
    }

    function _id(uint256 nonce, address to, uint256 amount) internal view returns (bytes32) {
        return keccak256(abi.encode(SRC, block.chainid, address(bridge), nonce, address(token), to, amount));
    }

    function testInitialConfiguration() public view {
        assertEq(bridge.threshold(), 2);
        assertEq(bridge.relayerCount(), 3);
        assertTrue(bridge.isRelayer(r1));
        assertFalse(bridge.isRelayer(alice));
        assertEq(bridge.transferId(SRC, 7, address(token), alice, 5 ether), _id(7, alice, 5 ether));
    }

    function testExecuteAfterThreshold() public {
        _attest(r1, 0, alice, 100 ether);
        assertEq(bridge.attestationCount(_id(0, alice, 100 ether)), 1);
        _attest(r2, 0, alice, 100 ether);

        vm.prank(bob); // anyone may execute
        bridge.execute(SRC, 0, address(token), alice, 100 ether);

        assertEq(token.balanceOf(alice), 100 ether);
        assertTrue(bridge.executed(_id(0, alice, 100 ether)));
        assertTrue(bridge.nonceUsed(SRC, 0));
    }

    function testExecuteBelowThresholdReverts() public {
        _attest(r1, 0, alice, 100 ether);
        vm.expectRevert(AttestedBridge.InsufficientAttestations.selector);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);
    }

    function testRelayerCannotAttestTwice() public {
        _attest(r1, 0, alice, 100 ether);
        vm.prank(r1);
        vm.expectRevert(AttestedBridge.AlreadyAttested.selector);
        bridge.attest(SRC, 0, address(token), alice, 100 ether);
    }

    function testNonRelayerCannotAttest() public {
        vm.prank(alice);
        vm.expectRevert(AttestedBridge.NotRelayer.selector);
        bridge.attest(SRC, 0, address(token), alice, 100 ether);
    }

    function testReplayReverts() public {
        _attest(r1, 0, alice, 100 ether);
        _attest(r2, 0, alice, 100 ether);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);

        vm.expectRevert(AttestedBridge.AlreadyExecuted.selector);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);
    }

    function testRateLimitCapsWindow() public {
        _attest(r1, 0, alice, 600 ether);
        _attest(r2, 0, alice, 600 ether);
        _attest(r1, 1, alice, 600 ether);
        _attest(r2, 1, alice, 600 ether);

        bridge.execute(SRC, 0, address(token), alice, 600 ether);
        assertEq(bridge.availableToRelease(address(token)), 400 ether);

        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 1, address(token), alice, 600 ether);

        vm.warp(block.timestamp + 1 hours);
        bridge.execute(SRC, 1, address(token), alice, 600 ether);
        assertEq(token.balanceOf(alice), 1_200 ether);
    }
}

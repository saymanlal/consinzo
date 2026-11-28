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

/// Token that calls back into the bridge while it is being transferred.
contract CallbackToken {
    mapping(address => uint256) public balanceOf;
    AttestedBridge public bridge;
    bytes public payload;
    bool public callbackSucceeded;
    bool public callbackTried;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function arm(AttestedBridge bridge_, bytes calldata payload_) external {
        bridge = bridge_;
        payload = payload_;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (payload.length != 0 && !callbackTried) {
            callbackTried = true;
            (bool ok,) = address(bridge).call(payload);
            callbackSucceeded = ok;
        }
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract AttestedBridgeHiddenTest is Test {
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

    function _both(uint256 nonce, address to, uint256 amount) internal {
        _attest(r1, nonce, to, amount);
        _attest(r2, nonce, to, amount);
    }

    // ------------------------------------------------------------ construction

    function testHiddenConstructorValidation() public {
        address[] memory rs = new address[](2);
        rs[0] = r1;
        rs[1] = r1;
        vm.expectRevert(AttestedBridge.DuplicateRelayer.selector);
        new AttestedBridge(rs, 1);

        rs[1] = address(0);
        vm.expectRevert(AttestedBridge.ZeroAddress.selector);
        new AttestedBridge(rs, 1);

        rs[1] = r2;
        vm.expectRevert(AttestedBridge.InvalidThreshold.selector);
        new AttestedBridge(rs, 0);
        vm.expectRevert(AttestedBridge.InvalidThreshold.selector);
        new AttestedBridge(rs, 3);

        AttestedBridge b = new AttestedBridge(rs, 2);
        assertEq(b.relayerCount(), 2);
    }

    function testHiddenAdminIsOwnerOnly() public {
        vm.startPrank(r1);
        vm.expectRevert(AttestedBridge.NotOwner.selector);
        bridge.addRelayer(alice);
        vm.expectRevert(AttestedBridge.NotOwner.selector);
        bridge.removeRelayer(r2);
        vm.expectRevert(AttestedBridge.NotOwner.selector);
        bridge.setThreshold(1);
        vm.expectRevert(AttestedBridge.NotOwner.selector);
        bridge.setRateLimit(address(token), 1);
        vm.stopPrank();
    }

    function testHiddenCommitteeManagementGuards() public {
        vm.expectRevert(AttestedBridge.ZeroAddress.selector);
        bridge.addRelayer(address(0));
        vm.expectRevert(AttestedBridge.DuplicateRelayer.selector);
        bridge.addRelayer(r1);
        vm.expectRevert(AttestedBridge.UnknownRelayer.selector);
        bridge.removeRelayer(alice);
        vm.expectRevert(AttestedBridge.InvalidThreshold.selector);
        bridge.setThreshold(0);
        vm.expectRevert(AttestedBridge.InvalidThreshold.selector);
        bridge.setThreshold(4);

        bridge.setThreshold(3);
        vm.expectRevert(AttestedBridge.InvalidThreshold.selector);
        bridge.removeRelayer(r3); // would leave 2 relayers for a threshold of 3

        bridge.setThreshold(2);
        bridge.removeRelayer(r3);
        assertEq(bridge.relayerCount(), 2);
        assertFalse(bridge.isRelayer(r3));
        vm.expectRevert(AttestedBridge.InvalidThreshold.selector);
        bridge.removeRelayer(r1);
    }

    // ------------------------------------------------------------- attestation

    function testHiddenAttestRejectsMalformedTransfers() public {
        vm.startPrank(r1);
        vm.expectRevert(AttestedBridge.InvalidTransfer.selector);
        bridge.attest(SRC, 0, address(0), alice, 1 ether);
        vm.expectRevert(AttestedBridge.InvalidTransfer.selector);
        bridge.attest(SRC, 0, address(token), address(0), 1 ether);
        vm.expectRevert(AttestedBridge.InvalidTransfer.selector);
        bridge.attest(SRC, 0, address(token), alice, 0);
        vm.stopPrank();

        // the relayer check comes first
        vm.prank(alice);
        vm.expectRevert(AttestedBridge.NotRelayer.selector);
        bridge.attest(SRC, 0, address(token), alice, 0);
    }

    function testHiddenAttestationsAreBoundToExactContents() public {
        _attest(r1, 0, alice, 100 ether);
        _attest(r2, 0, alice, 101 ether); // different amount
        _attest(r3, 0, bob, 100 ether); // different recipient
        vm.prank(r2);
        bridge.attest(SRC + 1, 0, address(token), alice, 100 ether); // different source chain

        assertEq(bridge.attestationCount(_id(0, alice, 100 ether)), 1);
        vm.expectRevert(AttestedBridge.InsufficientAttestations.selector);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);
        vm.expectRevert(AttestedBridge.InsufficientAttestations.selector);
        bridge.execute(SRC, 0, address(token), alice, 101 ether);
        assertEq(token.balanceOf(alice), 0);
    }

    function testHiddenAttestAfterExecutionReverts() public {
        _both(0, alice, 10 ether);
        bridge.execute(SRC, 0, address(token), alice, 10 ether);
        vm.prank(r3);
        vm.expectRevert(AttestedBridge.AlreadyExecuted.selector);
        bridge.attest(SRC, 0, address(token), alice, 10 ether);
        // an attester that already voted sees AlreadyExecuted too (it is checked first)
        vm.prank(r1);
        vm.expectRevert(AttestedBridge.AlreadyExecuted.selector);
        bridge.attest(SRC, 0, address(token), alice, 10 ether);
    }

    // ------------------------------------------------------------------ replay

    function testHiddenConflictingTransfersShareOneNonce() public {
        // The committee (or a compromised majority) attests to two contents for nonce 5.
        _both(5, alice, 100 ether);
        _attest(r2, 5, bob, 100 ether);
        _attest(r3, 5, bob, 100 ether);

        bridge.execute(SRC, 5, address(token), bob, 100 ether);
        vm.expectRevert(AttestedBridge.NonceAlreadyUsed.selector);
        bridge.execute(SRC, 5, address(token), alice, 100 ether);

        assertEq(token.balanceOf(bob), 100 ether);
        assertEq(token.balanceOf(alice), 0);
        assertFalse(bridge.executed(_id(5, alice, 100 ether)));
    }

    function testHiddenSameNonceOnAnotherSourceChainIsIndependent() public {
        _both(0, alice, 10 ether);
        vm.prank(r1);
        bridge.attest(SRC + 1, 0, address(token), alice, 10 ether);
        vm.prank(r3);
        bridge.attest(SRC + 1, 0, address(token), alice, 10 ether);

        bridge.execute(SRC, 0, address(token), alice, 10 ether);
        bridge.execute(SRC + 1, 0, address(token), alice, 10 ether);
        assertEq(token.balanceOf(alice), 20 ether);
        assertTrue(bridge.nonceUsed(SRC + 1, 0));
        assertFalse(bridge.nonceUsed(SRC + 2, 0));
    }

    function testHiddenIdIsBoundToThisBridge() public {
        address[] memory rs = new address[](2);
        rs[0] = r1;
        rs[1] = r2;
        AttestedBridge other = new AttestedBridge(rs, 2);
        assertTrue(
            other.transferId(SRC, 0, address(token), alice, 1 ether)
                != bridge.transferId(SRC, 0, address(token), alice, 1 ether)
        );
    }

    // --------------------------------------------------------- committee churn

    function testHiddenRemovedRelayerAttestationStopsCounting() public {
        _attest(r1, 0, alice, 100 ether);
        _attest(r3, 0, alice, 100 ether);
        bytes32 id = _id(0, alice, 100 ether);
        assertEq(bridge.attestationCount(id), 2);

        bridge.removeRelayer(r3);
        assertEq(bridge.attestationCount(id), 1);
        assertTrue(bridge.hasAttested(id, r3)); // the record remains, it just has no weight
        vm.expectRevert(AttestedBridge.InsufficientAttestations.selector);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);

        vm.prank(r3);
        vm.expectRevert(AttestedBridge.NotRelayer.selector);
        bridge.attest(SRC, 1, address(token), alice, 1 ether);

        _attest(r2, 0, alice, 100 ether);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
    }

    function testHiddenRemovingMiddleRelayerKeepsOthersCounted() public {
        _attest(r1, 0, alice, 1 ether);
        _attest(r2, 0, alice, 1 ether);
        _attest(r3, 0, alice, 1 ether);
        bridge.removeRelayer(r1); // first element of the list
        assertEq(bridge.attestationCount(_id(0, alice, 1 ether)), 2);
        assertEq(bridge.relayerCount(), 2);
        assertTrue(bridge.isRelayer(r2));
        assertTrue(bridge.isRelayer(r3));
        bridge.execute(SRC, 0, address(token), alice, 1 ether);
    }

    function testHiddenReaddedRelayerOldAttestationCountsAgain() public {
        _attest(r3, 0, alice, 1 ether);
        bridge.removeRelayer(r3);
        assertEq(bridge.attestationCount(_id(0, alice, 1 ether)), 0);
        bridge.addRelayer(r3);
        assertEq(bridge.attestationCount(_id(0, alice, 1 ether)), 1);
        vm.prank(r3);
        vm.expectRevert(AttestedBridge.AlreadyAttested.selector);
        bridge.attest(SRC, 0, address(token), alice, 1 ether);
    }

    function testHiddenThresholdChangeAppliesAtExecution() public {
        _both(0, alice, 1 ether);
        bridge.setThreshold(3);
        vm.expectRevert(AttestedBridge.InsufficientAttestations.selector);
        bridge.execute(SRC, 0, address(token), alice, 1 ether);

        _attest(r1, 1, alice, 1 ether);
        bridge.setThreshold(1);
        bridge.execute(SRC, 1, address(token), alice, 1 ether);
        bridge.execute(SRC, 0, address(token), alice, 1 ether);
        assertEq(token.balanceOf(alice), 2 ether);
    }

    function testHiddenNewRelayerCanAttest() public {
        bridge.addRelayer(bob);
        _attest(bob, 0, alice, 1 ether);
        _attest(r1, 0, alice, 1 ether);
        bridge.execute(SRC, 0, address(token), alice, 1 ether);
        assertEq(bridge.relayerCount(), 4);
    }

    // -------------------------------------------------------------- rate limit

    function testHiddenUnsupportedTokenCannotBeExecuted() public {
        MockERC20 other = new MockERC20();
        other.mint(address(bridge), 100 ether);
        vm.prank(r1);
        bridge.attest(SRC, 0, address(other), alice, 1 ether);
        vm.prank(r2);
        bridge.attest(SRC, 0, address(other), alice, 1 ether);

        vm.expectRevert(AttestedBridge.TokenNotSupported.selector);
        bridge.execute(SRC, 0, address(other), alice, 1 ether);
        assertFalse(bridge.nonceUsed(SRC, 0));

        bridge.setRateLimit(address(other), 1 ether);
        bridge.execute(SRC, 0, address(other), alice, 1 ether);
        assertEq(other.balanceOf(alice), 1 ether);
    }

    function testHiddenRateLimitExactBoundary() public {
        _both(0, alice, 400 ether);
        _both(1, alice, 600 ether);
        _both(2, alice, 1);
        bridge.execute(SRC, 0, address(token), alice, 400 ether);
        bridge.execute(SRC, 1, address(token), alice, 600 ether); // exactly reaches the limit
        assertEq(bridge.availableToRelease(address(token)), 0);

        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 2, address(token), alice, 1);
        assertFalse(bridge.executed(_id(2, alice, 1)));
        assertFalse(bridge.nonceUsed(SRC, 2));
    }

    function testHiddenSingleTransferAboveLimitNeverExecutes() public {
        _both(0, alice, 1_000 ether + 1);
        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 0, address(token), alice, 1_000 ether + 1);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 0, address(token), alice, 1_000 ether + 1);

        bridge.setRateLimit(address(token), 2_000 ether);
        bridge.execute(SRC, 0, address(token), alice, 1_000 ether + 1);
    }

    function testHiddenWindowStartsAtFirstExecutionNotAtDeployment() public {
        uint256 t0 = block.timestamp;
        _both(0, alice, 1_000 ether);
        _both(1, alice, 1_000 ether);

        vm.warp(t0 + 50 minutes);
        bridge.execute(SRC, 0, address(token), alice, 1_000 ether); // window: t0+50m .. t0+110m

        vm.warp(t0 + 61 minutes); // a clock-aligned hourly bucket would have rolled over here
        assertEq(bridge.availableToRelease(address(token)), 0);
        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 1, address(token), alice, 1_000 ether);

        vm.warp(t0 + 110 minutes - 1);
        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 1, address(token), alice, 1_000 ether);

        vm.warp(t0 + 110 minutes);
        assertEq(bridge.availableToRelease(address(token)), 1_000 ether);
        bridge.execute(SRC, 1, address(token), alice, 1_000 ether);
        assertEq(bridge.availableToRelease(address(token)), 0);
    }

    function testHiddenUnusedAllowanceDoesNotCarryOver() public {
        _both(0, alice, 100 ether);
        _both(1, alice, 1_000 ether);
        _both(2, alice, 1 ether);
        bridge.execute(SRC, 0, address(token), alice, 100 ether);
        vm.warp(block.timestamp + 3 hours);
        bridge.execute(SRC, 1, address(token), alice, 1_000 ether);
        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 2, address(token), alice, 1 ether);
    }

    function testHiddenLoweringLimitBelowSpentYieldsZeroAvailable() public {
        _both(0, alice, 800 ether);
        _both(1, alice, 1 ether);
        bridge.execute(SRC, 0, address(token), alice, 800 ether);

        bridge.setRateLimit(address(token), 500 ether);
        assertEq(bridge.availableToRelease(address(token)), 0);
        vm.expectRevert(AttestedBridge.RateLimitExceeded.selector);
        bridge.execute(SRC, 1, address(token), alice, 1 ether);

        bridge.setRateLimit(address(token), 900 ether); // raising does not reset the window
        assertEq(bridge.availableToRelease(address(token)), 100 ether);

        vm.warp(block.timestamp + 1 hours);
        assertEq(bridge.availableToRelease(address(token)), 900 ether);
    }

    function testHiddenRateLimitsArePerToken() public {
        MockERC20 other = new MockERC20();
        other.mint(address(bridge), 100 ether);
        bridge.setRateLimit(address(other), 50 ether);

        _both(0, alice, 1_000 ether);
        bridge.execute(SRC, 0, address(token), alice, 1_000 ether);

        vm.prank(r1);
        bridge.attest(SRC, 1, address(other), alice, 50 ether);
        vm.prank(r2);
        bridge.attest(SRC, 1, address(other), alice, 50 ether);
        bridge.execute(SRC, 1, address(other), alice, 50 ether);
        assertEq(bridge.availableToRelease(address(other)), 0);
        assertEq(other.balanceOf(alice), 50 ether);
    }

    // ------------------------------------------------------------ token quirks

    function testHiddenFalseReturningTokenRevertsAndStaysExecutable() public {
        _both(0, alice, 10 ether);
        token.setReturnFalse(true);
        vm.expectRevert(AttestedBridge.TransferFailed.selector);
        bridge.execute(SRC, 0, address(token), alice, 10 ether);
        assertFalse(bridge.executed(_id(0, alice, 10 ether)));
        assertEq(bridge.availableToRelease(address(token)), 1_000 ether);

        token.setReturnFalse(false);
        bridge.execute(SRC, 0, address(token), alice, 10 ether);
        assertEq(token.balanceOf(alice), 10 ether);
    }

    function testHiddenReentrantTokenCannotExecuteTwice() public {
        CallbackToken cb = new CallbackToken();
        cb.mint(address(bridge), 100 ether);
        bridge.setRateLimit(address(cb), 100 ether);
        vm.prank(r1);
        bridge.attest(SRC, 0, address(cb), alice, 10 ether);
        vm.prank(r2);
        bridge.attest(SRC, 0, address(cb), alice, 10 ether);

        cb.arm(bridge, abi.encodeCall(AttestedBridge.execute, (SRC, 0, address(cb), alice, 10 ether)));
        bridge.execute(SRC, 0, address(cb), alice, 10 ether);

        assertTrue(cb.callbackTried());
        assertFalse(cb.callbackSucceeded());
        assertEq(cb.balanceOf(alice), 10 ether);
        assertEq(bridge.availableToRelease(address(cb)), 90 ether);
    }
}

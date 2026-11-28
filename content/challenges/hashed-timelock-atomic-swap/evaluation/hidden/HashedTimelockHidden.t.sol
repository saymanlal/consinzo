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

/// Takes a 1% fee on every transfer.
contract FeeToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        uint256 fee = amount / 100;
        balanceOf[from] -= amount;
        balanceOf[to] += amount - fee;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _move(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        _move(from, to, amount);
        return true;
    }
}

/// transfer / transferFrom return no data (USDT style).
contract NoReturnToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
    }

    function transfer(address to, uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
    }

    function transferFrom(address from, address to, uint256 amount) external {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

/// Returns false instead of reverting. Outgoing transfers can be switched to fail.
contract FalseToken {
    mapping(address => uint256) public balanceOf;
    bool public failTransfers;
    bool public failPulls = true;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setFail(bool pulls, bool transfers) external {
        failPulls = pulls;
        failTransfers = transfers;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (failTransfers) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (failPulls) return false;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// Recipient that tries to take the same swap again when it is paid.
contract ReentrantRecipient {
    HashedTimelock public htlc;
    bytes32 public swapId;
    bytes32 public preimage;
    bool public reentered;
    uint256 public attempts;

    constructor(HashedTimelock htlc_) {
        htlc = htlc_;
    }

    function arm(bytes32 swapId_, bytes32 preimage_) external {
        swapId = swapId_;
        preimage = preimage_;
    }

    receive() external payable {
        attempts += 1;
        (bool a,) = address(htlc).call(abi.encodeWithSelector(HashedTimelock.claim.selector, swapId, preimage));
        (bool b,) = address(htlc).call(abi.encodeWithSelector(HashedTimelock.refund.selector, swapId));
        if (a || b) reentered = true;
    }
}

contract RejectingRecipient {
    // no receive function: ETH transfers to this contract fail
}

contract HashedTimelockHiddenTest is Test {
    HashedTimelock public htlc;
    HashedTimelock public other;
    MockERC20 public token;

    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public mallory = address(0xBAD);

    bytes32 internal constant SECRET = keccak256("hidden secret");
    bytes32 internal hashlock;
    uint64 internal t0;

    function setUp() public {
        htlc = new HashedTimelock();
        other = new HashedTimelock();
        token = new MockERC20();
        hashlock = sha256(abi.encodePacked(SECRET));
        t0 = uint64(block.timestamp);

        token.mint(alice, 1_000 ether);
        vm.prank(alice);
        token.approve(address(htlc), type(uint256).max);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function _state(HashedTimelock h, bytes32 id) internal view returns (uint256) {
        (,,,,,, HashedTimelock.State state) = h.swaps(id);
        return uint256(state);
    }

    function _amount(HashedTimelock h, bytes32 id) internal view returns (uint256 amount) {
        (,,, amount,,,) = h.swaps(id);
    }

    function testHiddenSwapIdFormula() public view {
        bytes32 expected = keccak256(abi.encode(alice, bob, address(token), uint256(5), hashlock, uint64(t0 + 9)));
        assertEq(htlc.computeSwapId(alice, bob, address(token), 5, hashlock, t0 + 9), expected);
    }

    function testHiddenLockValidationOrder() public {
        vm.prank(alice);
        vm.expectRevert(HashedTimelock.ZeroAddress.selector);
        htlc.lockETH{value: 0}(address(0), hashlock, t0);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.ZeroAmount.selector);
        htlc.lockETH{value: 0}(bob, hashlock, t0);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.InvalidTimelock.selector);
        htlc.lockETH{value: 1 ether}(bob, hashlock, t0); // timelock == now is not in the future

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.ZeroAddress.selector);
        htlc.lockToken(address(0), 0, bob, hashlock, t0);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.ZeroAddress.selector);
        htlc.lockToken(address(token), 1, address(0), hashlock, t0 + 1);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.ZeroAmount.selector);
        htlc.lockToken(address(token), 0, bob, hashlock, t0);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.InvalidTimelock.selector);
        htlc.lockToken(address(token), 1, bob, hashlock, t0 - 1);

        assertEq(address(htlc).balance, 0);
        assertEq(token.balanceOf(address(htlc)), 0);
    }

    function testHiddenSwapIdCannotBeReused() public {
        vm.prank(alice);
        bytes32 id = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.SwapExists.selector);
        htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);

        htlc.claim(id, SECRET);

        // still taken after the swap has been settled
        vm.prank(alice);
        vm.expectRevert(HashedTimelock.SwapExists.selector);
        htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);

        // any differing parameter gives a different swap
        vm.prank(alice);
        bytes32 id2 = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 101);
        assertTrue(id2 != id);
        vm.prank(bob);
        bytes32 id3 = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        assertTrue(id3 != id);
        assertEq(address(htlc).balance, 2 ether);
    }

    function testHiddenTimelockBoundaryIsExclusive() public {
        vm.prank(alice);
        bytes32 a = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        vm.prank(alice);
        bytes32 b = htlc.lockETH{value: 2 ether}(bob, hashlock, t0 + 100);

        vm.warp(t0 + 99);
        vm.expectRevert(HashedTimelock.NotExpired.selector);
        htlc.refund(a);
        htlc.claim(a, SECRET); // last valid second for a claim
        assertEq(bob.balance, 101 ether);

        vm.warp(t0 + 100);
        vm.expectRevert(HashedTimelock.Expired.selector);
        htlc.claim(b, SECRET); // correct preimage, but too late
        htlc.refund(b);
        assertEq(alice.balance, 99 ether);
        assertEq(address(htlc).balance, 0);
        assertEq(htlc.preimageOf(b), bytes32(0));
    }

    function testHiddenClaimCheckOrder() public {
        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        htlc.claim(keccak256("unknown"), SECRET);

        vm.prank(alice);
        bytes32 id = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        vm.warp(t0 + 500);
        vm.expectRevert(HashedTimelock.Expired.selector); // expiry is reported before the preimage
        htlc.claim(id, bytes32(0));

        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        htlc.refund(keccak256("unknown"));
    }

    function testHiddenNoDoubleSettlement() public {
        vm.prank(alice);
        bytes32 a = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        vm.prank(alice);
        bytes32 b = htlc.lockETH{value: 3 ether}(bob, hashlock, t0 + 200);

        htlc.claim(a, SECRET);
        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        htlc.claim(a, SECRET);

        vm.warp(t0 + 150);
        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        htlc.refund(a); // a claimed swap cannot also be refunded
        assertEq(address(htlc).balance, 3 ether);

        vm.warp(t0 + 200);
        htlc.refund(b);
        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        htlc.refund(b);
        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        htlc.claim(b, SECRET);

        assertEq(_state(htlc, a), uint256(HashedTimelock.State.Claimed));
        assertEq(_state(htlc, b), uint256(HashedTimelock.State.Refunded));
        assertEq(address(htlc).balance, 0);
        assertEq(bob.balance, 101 ether);
        assertEq(alice.balance, 99 ether);
    }

    function testHiddenHashIsSha256NotKeccak() public {
        bytes32 keccakLock = keccak256(abi.encodePacked(SECRET));
        vm.prank(alice);
        bytes32 id = htlc.lockETH{value: 1 ether}(bob, keccakLock, t0 + 100);
        vm.expectRevert(HashedTimelock.InvalidPreimage.selector);
        htlc.claim(id, SECRET);

        // the hashlock itself is not a valid preimage
        vm.prank(alice);
        bytes32 id2 = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        vm.expectRevert(HashedTimelock.InvalidPreimage.selector);
        htlc.claim(id2, hashlock);
        assertEq(_state(htlc, id2), uint256(HashedTimelock.State.Open));
    }

    function testHiddenThirdPartyCannotRedirectFunds() public {
        vm.prank(alice);
        bytes32 id = htlc.lockToken(address(token), 50 ether, bob, hashlock, t0 + 100);

        vm.prank(mallory);
        htlc.claim(id, SECRET);
        assertEq(token.balanceOf(mallory), 0);
        assertEq(token.balanceOf(bob), 50 ether);

        vm.prank(alice);
        bytes32 id2 = htlc.lockToken(address(token), 20 ether, bob, hashlock, t0 + 200);
        vm.warp(t0 + 200);
        vm.prank(mallory);
        htlc.refund(id2);
        assertEq(token.balanceOf(mallory), 0);
        assertEq(token.balanceOf(alice), 950 ether);
    }

    function testHiddenFeeOnTransferTokenUsesReceivedAmount() public {
        FeeToken fee = new FeeToken();
        fee.mint(alice, 1_000 ether);
        fee.mint(bob, 1_000 ether);
        vm.prank(alice);
        fee.approve(address(htlc), type(uint256).max);
        vm.prank(bob);
        fee.approve(address(htlc), type(uint256).max);

        vm.prank(alice);
        bytes32 a = htlc.lockToken(address(fee), 100 ether, bob, hashlock, t0 + 100);
        vm.prank(bob);
        bytes32 b = htlc.lockToken(address(fee), 100 ether, alice, hashlock, t0 + 100);

        assertEq(a, htlc.computeSwapId(alice, bob, address(fee), 100 ether, hashlock, t0 + 100));
        assertEq(_amount(htlc, a), 99 ether);
        assertEq(_amount(htlc, b), 99 ether);
        assertEq(fee.balanceOf(address(htlc)), 198 ether);

        // each swap pays only what it holds, so the second one is still fully funded
        htlc.claim(a, SECRET);
        assertEq(fee.balanceOf(address(htlc)), 99 ether);
        vm.warp(t0 + 100);
        htlc.refund(b);
        assertEq(fee.balanceOf(address(htlc)), 0);
    }

    function testHiddenTokenWithoutReturnValue() public {
        NoReturnToken usdt = new NoReturnToken();
        usdt.mint(alice, 500);
        vm.prank(alice);
        usdt.approve(address(htlc), 500);

        vm.prank(alice);
        bytes32 a = htlc.lockToken(address(usdt), 300, bob, hashlock, t0 + 100);
        vm.prank(alice);
        bytes32 b = htlc.lockToken(address(usdt), 200, bob, hashlock, t0 + 100);
        htlc.claim(a, SECRET);
        assertEq(usdt.balanceOf(bob), 300);
        vm.warp(t0 + 100);
        htlc.refund(b);
        assertEq(usdt.balanceOf(alice), 200);
    }

    function testHiddenTokenReturningFalse() public {
        FalseToken bad = new FalseToken();
        bad.mint(alice, 100);

        vm.prank(alice);
        vm.expectRevert(HashedTimelock.TransferFailed.selector);
        htlc.lockToken(address(bad), 100, bob, hashlock, t0 + 100);
        bytes32 id = htlc.computeSwapId(alice, bob, address(bad), 100, hashlock, t0 + 100);
        assertEq(_state(htlc, id), uint256(HashedTimelock.State.None));

        bad.setFail(false, true); // pulls work, payouts return false
        vm.prank(alice);
        id = htlc.lockToken(address(bad), 100, bob, hashlock, t0 + 100);
        vm.expectRevert(HashedTimelock.TransferFailed.selector);
        htlc.claim(id, SECRET);
        assertEq(_state(htlc, id), uint256(HashedTimelock.State.Open));
        assertEq(htlc.preimageOf(id), bytes32(0));

        bad.setFail(false, false);
        htlc.claim(id, SECRET);
        assertEq(bad.balanceOf(bob), 100);
    }

    function testHiddenReentrantRecipientPaidOnce() public {
        ReentrantRecipient r = new ReentrantRecipient(htlc);
        vm.prank(alice);
        bytes32 id = htlc.lockETH{value: 1 ether}(address(r), hashlock, t0 + 100);
        vm.prank(alice);
        htlc.lockETH{value: 5 ether}(bob, hashlock, t0 + 100); // someone else's funds
        r.arm(id, SECRET);

        htlc.claim(id, SECRET);
        assertEq(r.attempts(), 1);
        assertFalse(r.reentered());
        assertEq(address(r).balance, 1 ether);
        assertEq(address(htlc).balance, 5 ether);
    }

    function testHiddenRejectingRecipientLeavesSwapRefundable() public {
        RejectingRecipient r = new RejectingRecipient();
        vm.prank(alice);
        bytes32 id = htlc.lockETH{value: 1 ether}(address(r), hashlock, t0 + 100);

        vm.expectRevert(HashedTimelock.TransferFailed.selector);
        htlc.claim(id, SECRET);
        assertEq(_state(htlc, id), uint256(HashedTimelock.State.Open));

        vm.warp(t0 + 100);
        htlc.refund(id);
        assertEq(alice.balance, 100 ether);
    }

    function testHiddenAbortedSwapRefundsBothSides() public {
        token.mint(bob, 10 ether);
        vm.prank(bob);
        token.approve(address(other), 10 ether);

        vm.prank(alice);
        bytes32 idA = htlc.lockETH{value: 2 ether}(bob, hashlock, t0 + 2 hours);
        vm.prank(bob);
        bytes32 idB = other.lockToken(address(token), 10 ether, alice, hashlock, t0 + 1 hours);

        // Alice never reveals. Bob's shorter lock expires first.
        vm.warp(t0 + 1 hours);
        other.refund(idB);
        assertEq(token.balanceOf(bob), 10 ether);

        // Alice can no longer take Bob's side, so revealing now would only lose her funds.
        vm.expectRevert(HashedTimelock.SwapNotOpen.selector);
        other.claim(idB, SECRET);
        vm.expectRevert(HashedTimelock.NotExpired.selector);
        htlc.refund(idA);

        vm.warp(t0 + 2 hours);
        htlc.refund(idA);
        assertEq(alice.balance, 100 ether);
        assertEq(htlc.preimageOf(idA), bytes32(0));
    }

    function testHiddenSameIdOnTwoDeploymentsIsIndependent() public {
        vm.prank(alice);
        bytes32 a = htlc.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        vm.prank(alice);
        bytes32 b = other.lockETH{value: 1 ether}(bob, hashlock, t0 + 100);
        assertEq(a, b);

        htlc.claim(a, SECRET);
        assertEq(_state(other, b), uint256(HashedTimelock.State.Open));
        assertEq(other.preimageOf(b), bytes32(0));
        other.claim(b, SECRET);
        assertEq(bob.balance, 102 ether);
    }
}

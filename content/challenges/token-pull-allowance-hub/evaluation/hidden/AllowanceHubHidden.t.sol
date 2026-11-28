// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AllowanceHub.sol";

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

    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        _move(from, to, amount);
        return true;
    }

    function _move(address from, address to, uint256 amount) internal {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

/// Signals failure by returning false instead of reverting.
contract FalseToken is MockERC20 {
    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return false;
    }
}

/// Always reverts.
contract RevertingToken is MockERC20 {
    function transferFrom(address, address, uint256) external pure override returns (bool) {
        revert("TOKEN_PAUSED");
    }
}

/// Moves funds but returns no data at all (like some legacy tokens).
contract NoReturnToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transferFrom(address from, address to, uint256 amount) external {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
    }
}

/// A token that is also a spender and re-enters the hub while it is being transferred.
contract ReentrantToken is MockERC20 {
    AllowanceHub public hub;
    address public victim;
    address public receiver;
    bool public armed;
    bool public reentryAttempted;
    bool public reentrySucceeded;

    constructor(AllowanceHub hub_) {
        hub = hub_;
    }

    function attack(address victim_, address receiver_, uint160 amount) external {
        victim = victim_;
        receiver = receiver_;
        armed = true;
        hub.transferFrom(victim_, receiver_, amount, address(this));
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (armed) {
            armed = false;
            reentryAttempted = true;
            try hub.transferFrom(victim, receiver, uint160(amount), address(this)) {
                reentrySucceeded = true;
            } catch {}
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract AllowanceHubHiddenTest is Test {
    AllowanceHub public hub;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public spender = address(0x5EED);
    address public other = address(0x07E4);
    address public sink = address(0x51CC);
    uint48 public expiry;

    function setUp() public {
        hub = new AllowanceHub();
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        tokenA.mint(alice, 1_000 ether);
        tokenB.mint(alice, 1_000 ether);
        tokenA.mint(bob, 1_000 ether);
        vm.startPrank(alice);
        tokenA.approve(address(hub), type(uint256).max);
        tokenB.approve(address(hub), type(uint256).max);
        vm.stopPrank();
        vm.prank(bob);
        tokenA.approve(address(hub), type(uint256).max);
        expiry = uint48(block.timestamp + 1 days);
    }

    function _approve(address owner, address token, address spender_, uint160 amount) internal {
        vm.prank(owner);
        hub.approve(token, spender_, amount, expiry);
    }

    function _spendable(address owner, address token, address spender_) internal view returns (uint256) {
        return uint256(hub.spendable(owner, token, spender_));
    }

    // ------------------------------------------------------------ granting

    function testHiddenApproveValidation() public {
        vm.prank(alice);
        vm.expectRevert(AllowanceHub.ZeroAddress.selector);
        hub.approve(address(tokenA), address(0), 1, expiry);

        uint48 past = uint48(block.timestamp - 1);
        vm.prank(alice);
        vm.expectRevert(AllowanceHub.InvalidExpiration.selector);
        hub.approve(address(tokenA), spender, 1, past);

        // expiring in the current block is allowed and usable right now
        uint48 nowTs = uint48(block.timestamp);
        vm.prank(alice);
        hub.approve(address(tokenA), spender, 5 ether, nowTs);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 5 ether, address(tokenA));
        assertEq(tokenA.balanceOf(sink), 5 ether);
    }

    function testHiddenApproveReplacesRatherThanAdds() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        _approve(alice, address(tokenA), spender, 40 ether);
        assertEq(_spendable(alice, address(tokenA), spender), 40 ether);

        vm.prank(spender);
        vm.expectRevert(AllowanceHub.InsufficientAllowance.selector);
        hub.transferFrom(alice, sink, 41 ether, address(tokenA));
    }

    // ------------------------------------------------------------ spending

    function testHiddenExactAllowanceCanBeSpentOnce() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 100 ether, address(tokenA));
        assertEq(_spendable(alice, address(tokenA), spender), 0);
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.InsufficientAllowance.selector);
        hub.transferFrom(alice, sink, 1, address(tokenA));
        assertEq(tokenA.balanceOf(sink), 100 ether);
    }

    function testHiddenUnlimitedAllowanceIsNotDecreased() public {
        _approve(alice, address(tokenA), spender, type(uint160).max);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 400 ether, address(tokenA));
        vm.prank(spender);
        hub.transferFrom(alice, sink, 400 ether, address(tokenA));
        (uint160 amount,,) = hub.allowance(alice, address(tokenA), spender);
        assertEq(uint256(amount), uint256(type(uint160).max));
        assertEq(tokenA.balanceOf(sink), 800 ether);
    }

    function testHiddenExpiryBoundary() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        vm.warp(uint256(expiry)); // exactly at expiration: still usable
        assertEq(_spendable(alice, address(tokenA), spender), 100 ether);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 10 ether, address(tokenA));

        vm.warp(uint256(expiry) + 1);
        assertEq(_spendable(alice, address(tokenA), spender), 0);
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(alice, sink, 10 ether, address(tokenA));

        // the remaining amount is still stored; a new approval makes the pair usable again
        (uint160 amount,,) = hub.allowance(alice, address(tokenA), spender);
        assertEq(uint256(amount), 90 ether);
        uint48 later = uint48(block.timestamp + 1 hours);
        vm.prank(alice);
        hub.approve(address(tokenA), spender, 20 ether, later);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 20 ether, address(tokenA));
        assertEq(tokenA.balanceOf(sink), 30 ether);
    }

    function testHiddenNeverApprovedFailsAsExpired() public {
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(alice, sink, 1, address(tokenA));
        // even a zero-amount pull needs a live allowance
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(alice, sink, 0, address(tokenA));
    }

    function testHiddenZeroRecipientRejectedFirst() public {
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.ZeroAddress.selector);
        hub.transferFrom(alice, address(0), 1, address(tokenA));
    }

    function testHiddenIsolationAcrossOwnersTokensAndSpenders() public {
        _approve(alice, address(tokenA), spender, 100 ether);

        // different token of the same owner
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenB));
        // different owner of the same token
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(bob, sink, 1 ether, address(tokenA));
        // the owner herself is not a spender of her own allowance
        vm.prank(alice);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenA));

        _approve(bob, address(tokenA), other, 7 ether);
        vm.prank(other);
        hub.transferFrom(bob, sink, 7 ether, address(tokenA));
        assertEq(_spendable(alice, address(tokenA), spender), 100 ether);
        assertEq(tokenA.balanceOf(alice), 1_000 ether);
        assertEq(tokenA.balanceOf(bob), 993 ether);
    }

    // ------------------------------------------------------------ revocation

    function testHiddenRevokeClearsAllFieldsAndOnlyThatPair() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        _approve(alice, address(tokenB), spender, 100 ether);
        _approve(alice, address(tokenA), other, 100 ether);

        vm.prank(alice);
        hub.revoke(address(tokenA), spender);
        (uint160 amount, uint48 expiration, uint48 epoch) = hub.allowance(alice, address(tokenA), spender);
        assertEq(uint256(amount), 0);
        assertEq(uint256(expiration), 0);
        assertEq(uint256(epoch), 0);

        assertEq(_spendable(alice, address(tokenB), spender), 100 ether);
        assertEq(_spendable(alice, address(tokenA), other), 100 ether);

        // revoking something that does not exist is a no-op
        vm.prank(bob);
        hub.revoke(address(tokenB), other);
    }

    function testHiddenOnlyOwnerRevocationCounts() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        // bob revoking "his" allowance / spender must not touch alice
        vm.startPrank(bob);
        hub.revoke(address(tokenA), spender);
        hub.revokeSpender(spender);
        vm.stopPrank();
        assertEq(uint256(hub.nonces(alice, spender)), 0);
        assertEq(uint256(hub.nonces(bob, spender)), 1);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 100 ether, address(tokenA));
        assertEq(tokenA.balanceOf(sink), 100 ether);
    }

    function testHiddenReapprovalAfterRevokeSpenderDoesNotReviveOtherTokens() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        _approve(alice, address(tokenB), spender, 100 ether);
        _approve(alice, address(tokenA), other, 100 ether);

        vm.prank(alice);
        hub.revokeSpender(spender);
        assertEq(_spendable(alice, address(tokenA), spender), 0);
        assertEq(_spendable(alice, address(tokenB), spender), 0);
        // another spender is unaffected
        assertEq(_spendable(alice, address(tokenA), other), 100 ether);

        _approve(alice, address(tokenA), spender, 10 ether);
        (,, uint48 epoch) = hub.allowance(alice, address(tokenA), spender);
        assertEq(uint256(epoch), 1);
        assertEq(_spendable(alice, address(tokenA), spender), 10 ether);

        vm.prank(spender);
        hub.transferFrom(alice, sink, 10 ether, address(tokenA));

        // tokenB was approved in epoch 0 and stays dead
        assertEq(_spendable(alice, address(tokenB), spender), 0);
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceRevoked.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenB));
        assertEq(tokenB.balanceOf(sink), 0);
    }

    function testHiddenRevokedIsReportedBeforeExpired() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        vm.prank(alice);
        hub.revokeSpender(spender);
        vm.prank(alice);
        uint48 n = hub.revokeSpender(spender);
        assertEq(uint256(n), 2);
        vm.warp(uint256(expiry) + 10);
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.AllowanceRevoked.selector);
        hub.transferFrom(alice, sink, 1 ether, address(tokenA));
    }

    // ------------------------------------------------------------ batches

    function testHiddenBatchIsAtomic() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        _approve(alice, address(tokenB), spender, 10 ether);

        AllowanceHub.Pull[] memory pulls = new AllowanceHub.Pull[](2);
        pulls[0] = AllowanceHub.Pull(alice, address(tokenA), sink, 100 ether);
        pulls[1] = AllowanceHub.Pull(alice, address(tokenB), sink, 11 ether); // too much
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.InsufficientAllowance.selector);
        hub.batchTransferFrom(pulls);

        assertEq(tokenA.balanceOf(sink), 0);
        assertEq(_spendable(alice, address(tokenA), spender), 100 ether);
        assertEq(_spendable(alice, address(tokenB), spender), 10 ether);
    }

    function testHiddenBatchEntriesShareOneAllowance() public {
        _approve(alice, address(tokenA), spender, 100 ether);

        AllowanceHub.Pull[] memory pulls = new AllowanceHub.Pull[](3);
        pulls[0] = AllowanceHub.Pull(alice, address(tokenA), sink, 40 ether);
        pulls[1] = AllowanceHub.Pull(alice, address(tokenA), other, 40 ether);
        pulls[2] = AllowanceHub.Pull(alice, address(tokenA), sink, 40 ether); // 120 in total
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.InsufficientAllowance.selector);
        hub.batchTransferFrom(pulls);

        pulls[2].amount = 20 ether;
        vm.prank(spender);
        hub.batchTransferFrom(pulls);
        assertEq(tokenA.balanceOf(sink), 60 ether);
        assertEq(tokenA.balanceOf(other), 40 ether);
        assertEq(_spendable(alice, address(tokenA), spender), 0);
    }

    function testHiddenBatchUsesCallerAsSpender() public {
        _approve(alice, address(tokenA), spender, 100 ether);
        AllowanceHub.Pull[] memory pulls = new AllowanceHub.Pull[](1);
        pulls[0] = AllowanceHub.Pull(alice, address(tokenA), other, 1 ether);
        vm.prank(other);
        vm.expectRevert(AllowanceHub.AllowanceExpired.selector);
        hub.batchTransferFrom(pulls);

        AllowanceHub.Pull[] memory none = new AllowanceHub.Pull[](0);
        vm.prank(other);
        hub.batchTransferFrom(none); // an empty batch is a no-op
    }

    // ------------------------------------------------------------ misbehaving tokens

    function testHiddenFalseReturnAndRevertingTokensFail() public {
        FalseToken ft = new FalseToken();
        RevertingToken rt = new RevertingToken();
        _approve(alice, address(ft), spender, 100 ether);
        _approve(alice, address(rt), spender, 100 ether);

        vm.prank(spender);
        vm.expectRevert(AllowanceHub.TransferFailed.selector);
        hub.transferFrom(alice, sink, 1 ether, address(ft));
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.TransferFailed.selector);
        hub.transferFrom(alice, sink, 1 ether, address(rt));

        // a failed pull does not consume allowance
        assertEq(_spendable(alice, address(ft), spender), 100 ether);
        assertEq(_spendable(alice, address(rt), spender), 100 ether);
    }

    function testHiddenTokenWithoutReturnDataSucceeds() public {
        NoReturnToken nt = new NoReturnToken();
        nt.mint(alice, 50 ether);
        _approve(alice, address(nt), spender, 50 ether);
        vm.prank(spender);
        hub.transferFrom(alice, sink, 20 ether, address(nt));
        assertEq(nt.balanceOf(sink), 20 ether);
        assertEq(_spendable(alice, address(nt), spender), 30 ether);
    }

    function testHiddenAddressWithoutCodeIsNotAToken() public {
        address notAToken = address(0xDEAD01);
        _approve(alice, notAToken, spender, 100 ether);
        vm.prank(spender);
        vm.expectRevert(AllowanceHub.TransferFailed.selector);
        hub.transferFrom(alice, sink, 1 ether, notAToken);
    }

    function testHiddenReentrantTokenCannotSpendAllowanceTwice() public {
        ReentrantToken evil = new ReentrantToken(hub);
        evil.mint(alice, 300 ether);
        // the token contract itself is the approved spender
        _approve(alice, address(evil), address(evil), 100 ether);

        evil.attack(alice, sink, 100 ether);

        assertTrue(evil.reentryAttempted());
        assertFalse(evil.reentrySucceeded());
        assertEq(evil.balanceOf(sink), 100 ether);
        assertEq(evil.balanceOf(alice), 200 ether);
        assertEq(_spendable(alice, address(evil), address(evil)), 0);
    }
}

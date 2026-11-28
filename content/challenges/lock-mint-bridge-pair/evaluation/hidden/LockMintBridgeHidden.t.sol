// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LockMintBridge.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
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

/// Token whose transfers report failure by returning false instead of reverting.
contract FalseReturningToken {
    function transfer(address, uint256) external pure returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}

contract LockMintBridgeHiddenTest is Test {
    MockERC20 public canonical;
    SourceVault public vault;
    WrappedToken public wrapped;

    address public relayer = address(0x4E1A);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public carol = address(0xCA401);

    function setUp() public {
        canonical = new MockERC20();
        vault = new SourceVault(address(canonical), relayer);
        wrapped = new WrappedToken(relayer);

        canonical.mint(alice, 1_000 ether);
        canonical.mint(bob, 1_000 ether);
        vm.prank(alice);
        canonical.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        canonical.approve(address(vault), type(uint256).max);
    }

    function _bridge(address from, address to, uint256 amount) internal returns (uint256 nonce) {
        vm.prank(from);
        nonce = vault.lock(amount, to);
        vm.prank(relayer);
        wrapped.mint(nonce, to, amount);
    }

    function testHiddenConstructorsRejectZero() public {
        vm.expectRevert(SourceVault.ZeroAddress.selector);
        new SourceVault(address(0), relayer);
        vm.expectRevert(SourceVault.ZeroAddress.selector);
        new SourceVault(address(canonical), address(0));
        vm.expectRevert(WrappedToken.ZeroAddress.selector);
        new WrappedToken(address(0));
    }

    function testHiddenMetadata() public view {
        assertEq(wrapped.name(), "Wrapped Bridged Token");
        assertEq(wrapped.symbol(), "wBRG");
        assertEq(uint256(wrapped.decimals()), 18);
        assertEq(wrapped.relayer(), relayer);
        assertEq(vault.relayer(), relayer);
        assertEq(address(vault.token()), address(canonical));
    }

    function testHiddenLockValidation() public {
        vm.prank(alice);
        vm.expectRevert(SourceVault.ZeroAmount.selector);
        vault.lock(0, alice);

        vm.prank(alice);
        vm.expectRevert(SourceVault.ZeroAddress.selector);
        vault.lock(1 ether, address(0));

        assertEq(vault.depositCount(), 0);
        assertEq(vault.totalLocked(), 0);
    }

    function testHiddenLockWithoutAllowanceReverts() public {
        canonical.mint(carol, 10 ether);
        vm.prank(carol);
        vm.expectRevert();
        vault.lock(10 ether, carol);
        assertEq(vault.depositCount(), 0);
    }

    function testHiddenFalseReturningTokenIsRejected() public {
        FalseReturningToken bad = new FalseReturningToken();
        SourceVault v = new SourceVault(address(bad), relayer);
        vm.prank(alice);
        vm.expectRevert(SourceVault.TransferFailed.selector);
        v.lock(1 ether, alice);
        assertEq(v.totalLocked(), 0);
        assertEq(v.depositCount(), 0);
    }

    function testHiddenMintCheckOrder() public {
        // non-relayer with otherwise invalid arguments still sees NotRelayer
        vm.prank(alice);
        vm.expectRevert(WrappedToken.NotRelayer.selector);
        wrapped.mint(1, address(0), 0);

        vm.prank(relayer);
        vm.expectRevert(WrappedToken.ZeroAddress.selector);
        wrapped.mint(1, address(0), 0);

        vm.prank(relayer);
        vm.expectRevert(WrappedToken.ZeroAmount.selector);
        wrapped.mint(1, bob, 0);

        // failed attempts must not consume the nonce
        assertFalse(wrapped.processedDeposits(1));
        vm.prank(relayer);
        wrapped.mint(1, bob, 5 ether);
        assertEq(wrapped.balanceOf(bob), 5 ether);
    }

    function testHiddenReplayWithDifferentRecipientOrAmount() public {
        uint256 nonce = _bridge(alice, alice, 100 ether);

        vm.prank(relayer);
        vm.expectRevert(WrappedToken.AlreadyProcessed.selector);
        wrapped.mint(nonce, bob, 100 ether);

        vm.prank(relayer);
        vm.expectRevert(WrappedToken.AlreadyProcessed.selector);
        wrapped.mint(nonce, alice, 1);

        assertEq(wrapped.totalSupply(), 100 ether);
    }

    function testHiddenBurnValidationAndNonces() public {
        _bridge(alice, alice, 100 ether);

        vm.prank(alice);
        vm.expectRevert(WrappedToken.ZeroAmount.selector);
        wrapped.burn(0, alice);

        vm.prank(alice);
        vm.expectRevert(WrappedToken.ZeroAddress.selector);
        wrapped.burn(1 ether, address(0));

        vm.prank(alice);
        vm.expectRevert(WrappedToken.InsufficientBalance.selector);
        wrapped.burn(100 ether + 1, alice);

        vm.prank(bob); // holds nothing
        vm.expectRevert(WrappedToken.InsufficientBalance.selector);
        wrapped.burn(1, bob);

        assertEq(wrapped.burnCount(), 0);

        vm.prank(alice);
        uint256 b1 = wrapped.burn(30 ether, alice);
        vm.prank(alice);
        uint256 b2 = wrapped.burn(70 ether, carol);
        assertEq(b1, 1);
        assertEq(b2, 2);
        assertEq(wrapped.burnCount(), 2);
        assertEq(wrapped.totalSupply(), 0);
        assertEq(wrapped.balanceOf(alice), 0);
    }

    function testHiddenReleaseReplayAndCheckOrder() public {
        _bridge(alice, alice, 100 ether);
        vm.prank(alice);
        uint256 burnNonce = wrapped.burn(60 ether, carol);

        vm.prank(alice);
        vm.expectRevert(SourceVault.NotRelayer.selector);
        vault.release(burnNonce, address(0), 0);

        vm.prank(relayer);
        vm.expectRevert(SourceVault.ZeroAddress.selector);
        vault.release(burnNonce, address(0), 0);

        vm.prank(relayer);
        vm.expectRevert(SourceVault.ZeroAmount.selector);
        vault.release(burnNonce, carol, 0);

        vm.prank(relayer);
        vault.release(burnNonce, carol, 60 ether);
        assertTrue(vault.processedBurns(burnNonce));
        assertEq(canonical.balanceOf(carol), 60 ether);

        vm.prank(relayer);
        vm.expectRevert(SourceVault.AlreadyProcessed.selector);
        vault.release(burnNonce, carol, 60 ether);

        vm.prank(relayer);
        vm.expectRevert(SourceVault.AlreadyProcessed.selector);
        vault.release(burnNonce, alice, 1);

        assertEq(vault.totalLocked(), 40 ether);
        assertEq(canonical.balanceOf(address(vault)), 40 ether);
    }

    function testHiddenDonationsCannotBeReleased() public {
        _bridge(alice, alice, 10 ether);
        // bob sends tokens straight to the vault without locking
        vm.prank(bob);
        canonical.transfer(address(vault), 500 ether);
        assertEq(vault.totalLocked(), 10 ether);

        vm.prank(relayer);
        vm.expectRevert(SourceVault.InsufficientLocked.selector);
        vault.release(7, bob, 10 ether + 1);
        assertFalse(vault.processedBurns(7));

        vm.prank(relayer);
        vault.release(7, bob, 10 ether);
        assertEq(vault.totalLocked(), 0);
        assertEq(canonical.balanceOf(address(vault)), 500 ether);
    }

    function testHiddenOutOfOrderRelayKeepsInvariant() public {
        vm.prank(alice);
        uint256 d1 = vault.lock(100 ether, alice);
        vm.prank(bob);
        uint256 d2 = vault.lock(250 ether, bob);
        vm.prank(alice);
        uint256 d3 = vault.lock(1, carol);
        assertEq(d3, 3);

        // relayer delivers in reverse order
        vm.startPrank(relayer);
        wrapped.mint(d3, carol, 1);
        wrapped.mint(d2, bob, 250 ether);
        wrapped.mint(d1, alice, 100 ether);
        vm.stopPrank();
        assertEq(wrapped.totalSupply(), vault.totalLocked());

        vm.prank(bob);
        uint256 b1 = wrapped.burn(200 ether, bob);
        vm.prank(carol);
        uint256 b2 = wrapped.burn(1, carol);

        vm.startPrank(relayer);
        vault.release(b2, carol, 1);
        vault.release(b1, bob, 200 ether);
        vm.stopPrank();

        assertEq(wrapped.totalSupply(), 150 ether);
        assertEq(vault.totalLocked(), 150 ether);
        assertEq(canonical.balanceOf(address(vault)), 150 ether);
        assertEq(canonical.balanceOf(bob), 950 ether);
        assertEq(canonical.balanceOf(carol), 1);
    }

    function testHiddenWrappedTransferFromStillWorksAfterBridge() public {
        _bridge(alice, alice, 100 ether);
        vm.prank(alice);
        wrapped.approve(bob, 30 ether);
        vm.prank(bob);
        wrapped.transferFrom(alice, carol, 30 ether);
        assertEq(wrapped.balanceOf(carol), 30 ether);

        // carol can bridge back what she received
        vm.prank(carol);
        uint256 burnNonce = wrapped.burn(30 ether, carol);
        vm.prank(relayer);
        vault.release(burnNonce, carol, 30 ether);
        assertEq(canonical.balanceOf(carol), 30 ether);
        assertEq(wrapped.totalSupply(), vault.totalLocked());
    }
}

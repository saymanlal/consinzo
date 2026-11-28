// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RfqSettlement.sol";

contract MockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// The harness has no vm.sign. Signatures below were produced off-chain for the maker key
/// 0xA11CE against the EIP-712 domain of the settlement deployed first in setUp(). Contract
/// addresses are deterministic in the harness, so the deployment order in setUp() must not change.
contract RfqSettlementTest is Test {
    RfqSettlement public settlement;
    MockToken public tokenA; // maker sells
    MockToken public tokenB; // maker buys
    address public maker;

    uint256 internal constant EXPIRY = 1_700_001_000;
    bytes32 internal constant ORDER1_DIGEST = 0xdb1840131d9e13c7f6cb93c3a4f7e2bc1863b7fc345b6ccedb1743969cd24670;
    bytes internal constant ORDER1_SIG =
        hex"3ba5b141c39841e9d5a8a0cf9981666ab8c942d12812f05f9d25907dc8507d81"
        hex"6cbb818f33e7e8d53f8e8645195e11d678ed77958c960b1f81d44357f43b59fc"
        hex"1b";

    function setUp() public {
        settlement = new RfqSettlement();
        tokenA = new MockToken();
        tokenB = new MockToken();
        maker = vm.addr(0xA11CE);

        tokenA.mint(maker, 10_000 ether);
        vm.prank(maker);
        tokenA.approve(address(settlement), type(uint256).max);

        tokenB.mint(address(this), 10_000 ether);
        tokenB.approve(address(settlement), type(uint256).max);
    }

    /// Order 1: maker sells 1000 A for 500 B, open to any taker, nonce 1.
    function _order1() internal view returns (RfqSettlement.Order memory) {
        return
            RfqSettlement.Order({
                maker: maker,
                taker: address(0),
                makerToken: address(tokenA),
                takerToken: address(tokenB),
                makerAmount: 1000 ether,
                takerAmount: 500 ether,
                nonce: 1,
                expiry: EXPIRY
            });
    }

    function testDeploymentMatchesSignedDomain() public view {
        assertEq(address(settlement), 0x97B0aBF484ECbcc9c901f4CfD91C5842d7DDb623, "settlement address changed");
        assertEq(address(tokenA), 0x5F3Afa681bcca1Ad2F1bE81e10B9e1Cb754DC3C4, "tokenA address changed");
        assertEq(address(tokenB), 0x38F38379fBde8656B3A5871dE3596013eBEA73b2, "tokenB address changed");
        assertEq(maker, 0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7);
        assertEq(block.chainid, 1);
        assertEq(
            settlement.DOMAIN_SEPARATOR(),
            bytes32(0xa94c8ced2e0d8b278d81f0c64d91f85f1f202038f8e2e7edd6c419bedbc16d7e)
        );
    }

    function testHashOrderIsEip712Digest() public view {
        assertEq(settlement.hashOrder(_order1()), ORDER1_DIGEST);
    }

    function testFillWithSignature() public {
        uint256 got = settlement.fill(_order1(), ORDER1_SIG, 500 ether);
        assertEq(got, 1000 ether);
        assertEq(tokenA.balanceOf(address(this)), 1000 ether);
        assertEq(tokenA.balanceOf(maker), 9000 ether);
        assertEq(tokenB.balanceOf(maker), 500 ether);
        assertEq(tokenB.balanceOf(address(this)), 9500 ether);
        assertEq(settlement.filledTakerAmount(ORDER1_DIGEST), 500 ether);
        assertTrue(settlement.isNonceUsed(maker, 1));
    }

    function testPartialFillsAccumulate() public {
        assertEq(settlement.fill(_order1(), ORDER1_SIG, 200 ether), 400 ether);
        assertEq(settlement.filledTakerAmount(ORDER1_DIGEST), 200 ether);
        assertFalse(settlement.isNonceUsed(maker, 1));
        assertEq(settlement.remainingTakerAmount(_order1()), 300 ether);

        assertEq(settlement.fill(_order1(), ORDER1_SIG, 300 ether), 600 ether);
        assertTrue(settlement.isNonceUsed(maker, 1));
        assertEq(settlement.remainingTakerAmount(_order1()), 0);
        assertEq(tokenA.balanceOf(address(this)), 1000 ether);
        assertEq(tokenB.balanceOf(maker), 500 ether);

        vm.expectRevert(RfqSettlement.NonceUsed.selector);
        settlement.fill(_order1(), ORDER1_SIG, 1);
    }

    function testOverfillReverts() public {
        settlement.fill(_order1(), ORDER1_SIG, 200 ether);
        vm.expectRevert(RfqSettlement.Overfill.selector);
        settlement.fill(_order1(), ORDER1_SIG, 300 ether + 1);
    }

    function testTamperedOrderRejected() public {
        RfqSettlement.Order memory o = _order1();
        o.makerAmount = 2000 ether;
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, ORDER1_SIG, 500 ether);
    }

    function testPreApprovedOrderNeedsNoSignature() public {
        RfqSettlement.Order memory o = _order1();
        o.nonce = 7;
        o.makerAmount = 90 ether;
        o.takerAmount = 30 ether;

        vm.expectRevert(RfqSettlement.NotAuthorised.selector);
        settlement.fill(o, "", 30 ether);

        vm.prank(maker);
        settlement.preApprove(o);
        assertTrue(settlement.preApproved(settlement.hashOrder(o)));

        assertEq(settlement.fill(o, "", 10 ether), 30 ether);
        assertEq(tokenA.balanceOf(address(this)), 30 ether);
        assertEq(tokenB.balanceOf(maker), 10 ether);
    }

    function testInvalidatedNonceBlocksFill() public {
        vm.prank(maker);
        settlement.invalidateNonce(1);
        assertTrue(settlement.isNonceUsed(maker, 1));
        vm.expectRevert(RfqSettlement.NonceUsed.selector);
        settlement.fill(_order1(), ORDER1_SIG, 100 ether);
    }

    function testExpiredOrderReverts() public {
        vm.warp(EXPIRY + 1);
        vm.expectRevert(RfqSettlement.OrderExpired.selector);
        settlement.fill(_order1(), ORDER1_SIG, 100 ether);
    }
}

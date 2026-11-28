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

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// Returns false instead of reverting when the transfer cannot happen.
contract FalseToken {
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return false;
    }
}

/// Old-style token: transferFrom returns nothing.
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

/// Taker token that tries to fill the same order again from inside transferFrom.
contract ReentrantToken is MockToken {
    RfqSettlement internal target;
    RfqSettlement.Order internal order;
    uint256 internal amount;
    bool internal armed;
    bool public reentered;

    function arm(RfqSettlement target_, RfqSettlement.Order memory order_, uint256 amount_) external {
        target = target_;
        order = order_;
        amount = amount_;
        armed = true;
        balanceOf[address(this)] += amount_;
        allowance[address(this)][address(target_)] = amount_;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (armed) {
            armed = false;
            try target.fill(order, "", amount) {
                reentered = true;
            } catch {}
        }
        return super.transferFrom(from, to, value);
    }
}

contract Wallet1271 {
    mapping(bytes32 => bool) public ok;
    bool public broken;

    function allow(bytes32 digest) external {
        ok[digest] = true;
    }

    function setBroken(bool b) external {
        broken = b;
    }

    function approveToken(MockToken token, address spender) external {
        token.approve(spender, type(uint256).max);
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        require(!broken, "broken");
        if (ok[hash] && signature.length == 3) return 0x1626ba7e;
        return 0xffffffff;
    }
}

contract RfqSettlementHiddenTest is Test {
    RfqSettlement public settlement;
    MockToken public tokenA;
    MockToken public tokenB;
    address public maker;
    address public bob = address(0xB0B);

    uint256 internal constant EXPIRY = 1_700_001_000;
    bytes32 internal constant R1 = 0x3ba5b141c39841e9d5a8a0cf9981666ab8c942d12812f05f9d25907dc8507d81;
    bytes32 internal constant S1 = 0x6cbb818f33e7e8d53f8e8645195e11d678ed77958c960b1f81d44357f43b59fc;
    bytes32 internal constant S1_HIGH = 0x93447e70cc18172ac07179bae6a1ee2841c1655122b2951c3dfe1b34dbfae745;
    bytes32 internal constant R2 = 0xc98e2ee82c351251a1ba7563c54d6c958ea881927177ba6ed8ca12a17acc776d;
    bytes32 internal constant S2 = 0x0aacec6ff886b1bccf35f58655a04377a41dddc5142a880df059e2e376352aee;
    bytes32 internal constant S2_HIGH = 0xf553139007794e4330ca0a79aa5fbc871690ff219b1e182dcf787ba95a011653;
    // Order 1 digest signed by a key that is not the maker's.
    bytes32 internal constant R1_OTHER = 0x47d46efea59e88b26d8c6b24ca69054c839a741326f79b04f4eb97c2c191c457;
    bytes32 internal constant S1_OTHER = 0x2619bb5d5f6206370a1cae648782cc74d1642994ef2ab1274d6541c64d7532bf;

    function setUp() public {
        // Same deployment order as the public suite: the signatures bind these addresses.
        settlement = new RfqSettlement();
        tokenA = new MockToken();
        tokenB = new MockToken();
        maker = vm.addr(0xA11CE);

        tokenA.mint(maker, 10_000 ether);
        vm.prank(maker);
        tokenA.approve(address(settlement), type(uint256).max);

        tokenB.mint(address(this), 10_000 ether);
        tokenB.approve(address(settlement), type(uint256).max);
        tokenB.mint(bob, 10_000 ether);
        vm.prank(bob);
        tokenB.approve(address(settlement), type(uint256).max);
    }

    function _order(uint256 nonce, uint256 makerAmount, uint256 takerAmount)
        internal
        view
        returns (RfqSettlement.Order memory)
    {
        return
            RfqSettlement.Order({
                maker: maker,
                taker: address(0),
                makerToken: address(tokenA),
                takerToken: address(tokenB),
                makerAmount: makerAmount,
                takerAmount: takerAmount,
                nonce: nonce,
                expiry: EXPIRY
            });
    }

    function _order1() internal view returns (RfqSettlement.Order memory) {
        return _order(1, 1000 ether, 500 ether);
    }

    /// Order 2: maker sells 300 A for 900 B, only bob may fill, nonce 257.
    function _order2() internal view returns (RfqSettlement.Order memory o) {
        o = _order(257, 300 ether, 900 ether);
        o.taker = bob;
    }

    function _approved(uint256 nonce, uint256 makerAmount, uint256 takerAmount)
        internal
        returns (RfqSettlement.Order memory o)
    {
        o = _order(nonce, makerAmount, takerAmount);
        vm.prank(maker);
        settlement.preApprove(o);
    }

    function _sig(bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes memory) {
        return abi.encodePacked(r, s, v);
    }

    // ------------------------------------------------------------ signatures

    function testHiddenTakerRestrictedOrder() public {
        RfqSettlement.Order memory o = _order2();
        vm.expectRevert(RfqSettlement.NotTaker.selector);
        settlement.fill(o, _sig(R2, S2, 28), 90 ether);

        vm.prank(bob);
        uint256 got = settlement.fill(o, _sig(R2, S2, 28), 90 ether);
        assertEq(got, 30 ether);
        assertEq(tokenA.balanceOf(bob), 30 ether);
        assertEq(tokenB.balanceOf(maker), 90 ether);
        assertEq(tokenB.balanceOf(address(this)), 10_000 ether);
    }

    function testHiddenHighSTwinRejected() public {
        RfqSettlement.Order memory o = _order2();
        vm.prank(bob);
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R2, S2_HIGH, 27), 90 ether);

        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(_order1(), _sig(R1, S1_HIGH, 28), 100 ether);
    }

    function testHiddenMalformedSignaturesRejected() public {
        RfqSettlement.Order memory o = _order1();
        // wrong signer
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1_OTHER, S1_OTHER, 28), 100 ether);
        // 64-byte signature
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, abi.encodePacked(R1, S1), 100 ether);
        // 66-byte signature
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, abi.encodePacked(R1, S1, uint8(27), uint8(0)), 100 ether);
        // v given as 0 instead of 27
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1, S1, 0), 100 ether);
        // flipped v recovers a different address
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1, S1, 28), 100 ether);
        // garbage that makes ecrecover return address(0) must not authorise a zero maker
        o.maker = address(0);
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(bytes32(0), bytes32(uint256(1)), 27), 100 ether);
        // the genuine signature still works afterwards
        assertEq(settlement.fill(_order1(), _sig(R1, S1, 27), 100 ether), 200 ether);
    }

    function testHiddenSignatureBoundToContract() public {
        RfqSettlement other = new RfqSettlement();
        assertNotEq(uint256(other.DOMAIN_SEPARATOR()), uint256(settlement.DOMAIN_SEPARATOR()));
        vm.prank(maker);
        tokenA.approve(address(other), type(uint256).max);
        tokenB.approve(address(other), type(uint256).max);
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        other.fill(_order1(), _sig(R1, S1, 27), 100 ether);
    }

    function testHiddenSignatureDoesNotCoverOtherFields() public {
        RfqSettlement.Order memory o = _order1();
        o.nonce = 2;
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1, S1, 27), 100 ether);
        o = _order1();
        o.expiry = EXPIRY + 1;
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1, S1, 27), 100 ether);
        o = _order1();
        o.taker = address(this);
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1, S1, 27), 100 ether);
        o = _order1();
        o.takerToken = address(tokenA);
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, _sig(R1, S1, 27), 100 ether);
    }

    // ------------------------------------------------------------ fills and rounding

    function testHiddenRoundingFavoursMaker() public {
        RfqSettlement.Order memory o = _approved(3, 7, 10);
        assertEq(settlement.fill(o, "", 3), 2); // 3 * 7 / 10 = 2.1
        vm.expectRevert(RfqSettlement.ZeroFill.selector);
        settlement.fill(o, "", 1); // 0.7 rounds to nothing
        assertEq(settlement.fill(o, "", 7), 4); // 4.9
        assertEq(tokenA.balanceOf(address(this)), 6);
        assertEq(tokenB.balanceOf(maker), 10);
        assertTrue(settlement.isNonceUsed(maker, 3));
        assertEq(settlement.remainingTakerAmount(o), 0);
    }

    function testHiddenZeroAndInvalidAmounts() public {
        RfqSettlement.Order memory o = _approved(4, 100, 100);
        vm.expectRevert(RfqSettlement.ZeroFill.selector);
        settlement.fill(o, "", 0);

        RfqSettlement.Order memory z = _order(5, 0, 100);
        vm.expectRevert(RfqSettlement.InvalidOrder.selector);
        settlement.fill(z, "", 10);
        z = _order(5, 100, 0);
        vm.expectRevert(RfqSettlement.InvalidOrder.selector);
        settlement.fill(z, "", 10);
    }

    function testHiddenExpiryBoundary() public {
        RfqSettlement.Order memory o = _approved(6, 100, 100);
        vm.warp(EXPIRY);
        assertEq(settlement.fill(o, "", 40), 40);
        assertEq(settlement.remainingTakerAmount(o), 60);
        vm.warp(EXPIRY + 1);
        assertEq(settlement.remainingTakerAmount(o), 0);
        vm.expectRevert(RfqSettlement.OrderExpired.selector);
        settlement.fill(o, "", 40);
    }

    function testHiddenFailedPaymentLeavesOrderUntouched() public {
        RfqSettlement.Order memory o = _approved(8, 100 ether, 100 ether);
        address carol = address(0xCA201);
        vm.prank(carol); // carol holds no tokenB
        vm.expectRevert(RfqSettlement.TransferFailed.selector);
        settlement.fill(o, "", 100 ether);
        assertEq(settlement.filledTakerAmount(settlement.hashOrder(o)), 0);
        assertFalse(settlement.isNonceUsed(maker, 8));
        assertEq(settlement.fill(o, "", 100 ether), 100 ether);
    }

    // ------------------------------------------------------------ nonces and approvals

    function testHiddenNonceBitmapLayout() public {
        vm.prank(maker);
        settlement.invalidateNonces(1, (1 << 1) | (1 << 255));
        assertEq(settlement.nonceBitmap(maker, 1), (1 << 1) | (1 << 255));
        assertTrue(settlement.isNonceUsed(maker, 257));
        assertTrue(settlement.isNonceUsed(maker, 511));
        assertFalse(settlement.isNonceUsed(maker, 256));
        assertFalse(settlement.isNonceUsed(maker, 258));
        assertFalse(settlement.isNonceUsed(maker, 1));
        assertFalse(settlement.isNonceUsed(maker, 512));

        vm.prank(maker);
        settlement.invalidateNonce(256);
        assertEq(settlement.nonceBitmap(maker, 1), (1 << 1) | (1 << 255) | 1);

        RfqSettlement.Order memory o = _order2();
        vm.prank(bob);
        vm.expectRevert(RfqSettlement.NonceUsed.selector);
        settlement.fill(o, _sig(R2, S2, 28), 90 ether);
        // order 1 lives in word 0 and is unaffected
        assertEq(settlement.fill(_order1(), _sig(R1, S1, 27), 500 ether), 1000 ether);
        assertEq(settlement.nonceBitmap(maker, 0), 2);
    }

    function testHiddenOnlyMakerControlsOwnNonces() public {
        vm.prank(bob);
        settlement.invalidateNonce(1);
        vm.prank(bob);
        settlement.invalidateNonces(0, type(uint256).max);
        assertFalse(settlement.isNonceUsed(maker, 1));
        assertTrue(settlement.isNonceUsed(bob, 1));
        assertEq(settlement.fill(_order1(), _sig(R1, S1, 27), 100 ether), 200 ether);
    }

    function testHiddenPreApproveOnlyByMaker() public {
        RfqSettlement.Order memory o = _order(9, 100, 100);
        vm.prank(bob);
        vm.expectRevert(RfqSettlement.NotMaker.selector);
        settlement.preApprove(o);
        assertFalse(settlement.preApproved(settlement.hashOrder(o)));
        vm.expectRevert(RfqSettlement.NotAuthorised.selector);
        settlement.fill(o, "", 10);
    }

    function testHiddenPreApprovalIsPerOrder() public {
        RfqSettlement.Order memory o = _approved(10, 100, 100);
        o.makerAmount = 1000; // a better price the maker never approved
        vm.expectRevert(RfqSettlement.NotAuthorised.selector);
        settlement.fill(o, "", 10);
    }

    function testHiddenSharedNonceCancelsSiblingOnFullFill() public {
        RfqSettlement.Order memory a = _approved(11, 100, 100);
        RfqSettlement.Order memory b = _approved(11, 100, 200);
        settlement.fill(a, "", 60);
        assertFalse(settlement.isNonceUsed(maker, 11));
        // partial fill of one quote does not block the sibling yet
        assertEq(settlement.fill(b, "", 20), 10);
        settlement.fill(a, "", 40);
        assertTrue(settlement.isNonceUsed(maker, 11));
        vm.expectRevert(RfqSettlement.NonceUsed.selector);
        settlement.fill(b, "", 20);
        assertEq(settlement.remainingTakerAmount(b), 0);
    }

    // ------------------------------------------------------------ contract makers

    function testHiddenContractMakerUsesErc1271() public {
        Wallet1271 wallet = new Wallet1271();
        tokenA.mint(address(wallet), 500 ether);
        wallet.approveToken(tokenA, address(settlement));
        RfqSettlement.Order memory o = _order(1, 500 ether, 250 ether);
        o.maker = address(wallet);
        bytes32 digest = settlement.hashOrder(o);

        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, hex"010203", 50 ether);

        wallet.allow(digest);
        // the wallet rejects this signature blob (wrong length), so the magic value is not returned
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, hex"0102", 50 ether);

        assertEq(settlement.fill(o, hex"010203", 50 ether), 100 ether);
        assertEq(tokenB.balanceOf(address(wallet)), 50 ether);
        assertEq(tokenA.balanceOf(address(wallet)), 400 ether);

        wallet.setBroken(true);
        vm.expectRevert(RfqSettlement.InvalidSignature.selector);
        settlement.fill(o, hex"010203", 50 ether);

        // an empty signature always means the pre-approval path
        wallet.setBroken(false);
        vm.expectRevert(RfqSettlement.NotAuthorised.selector);
        settlement.fill(o, "", 50 ether);
    }

    // ------------------------------------------------------------ token behaviour

    function testHiddenReentrantTakerTokenCannotOverfill() public {
        ReentrantToken evil = new ReentrantToken();
        RfqSettlement.Order memory o = _order(12, 100 ether, 100 ether);
        o.takerToken = address(evil);
        vm.prank(maker);
        settlement.preApprove(o);

        evil.mint(address(this), 100 ether);
        evil.approve(address(settlement), type(uint256).max);
        evil.arm(settlement, o, 100 ether);

        assertEq(settlement.fill(o, "", 100 ether), 100 ether);
        assertFalse(evil.reentered());
        assertEq(tokenA.balanceOf(maker), 10_000 ether - 100 ether);
        assertEq(tokenA.balanceOf(address(evil)), 0);
        assertEq(settlement.filledTakerAmount(settlement.hashOrder(o)), 100 ether);
    }

    function testHiddenFalseReturningTokenReverts() public {
        FalseToken bad = new FalseToken();
        RfqSettlement.Order memory o = _order(13, 100, 100);
        o.takerToken = address(bad);
        vm.prank(maker);
        settlement.preApprove(o);
        vm.expectRevert(RfqSettlement.TransferFailed.selector);
        settlement.fill(o, "", 100);
        assertEq(tokenA.balanceOf(address(this)), 0);
    }

    function testHiddenNoReturnTokenAccepted() public {
        NoReturnToken old = new NoReturnToken();
        old.mint(address(this), 100);
        RfqSettlement.Order memory o = _order(14, 50, 100);
        o.takerToken = address(old);
        vm.prank(maker);
        settlement.preApprove(o);
        assertEq(settlement.fill(o, "", 100), 50);
        assertEq(old.balanceOf(maker), 100);
        assertEq(tokenA.balanceOf(address(this)), 50);
    }
}

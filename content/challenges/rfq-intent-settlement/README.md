# RFQ Intent Settlement with Partial Fills and a Nonce Bitmap

## Problem Statement

Implement `RfqSettlement` in `src/RfqSettlement.sol`. A maker quotes a fixed price off-chain
as an `Order`. Any allowed taker can settle all or part of that order on-chain. The contract
must verify that the maker authorised exactly this order, keep track of how much has been
filled, let makers cancel through a nonce bitmap, and move both tokens atomically.

The struct, errors, events and constants are already declared in the starter.

```solidity
struct Order {
    address maker;
    address taker;       // address(0): anyone may fill
    address makerToken;  // token the maker sells
    address takerToken;  // token the maker buys
    uint256 makerAmount;
    uint256 takerAmount;
    uint256 nonce;
    uint256 expiry;      // last timestamp at which the order can be filled
}
```

## Order Digest (EIP-712)

- Domain: `EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)`
  with `name = "ConsinzoRFQ"`, `version = "1"`, `chainId = block.chainid`,
  `verifyingContract = address(this)`. Store its hash in `DOMAIN_SEPARATOR`.
- Struct hash: `keccak256(abi.encode(ORDER_TYPEHASH, maker, taker, makerToken, takerToken, makerAmount, takerAmount, nonce, expiry))`.
- `hashOrder(order) = keccak256("\x19\x01" || DOMAIN_SEPARATOR || structHash)`.

## Required Interface

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32);
function hashOrder(Order calldata order) external view returns (bytes32);

function nonceBitmap(address maker, uint256 wordPos) external view returns (uint256);
function isNonceUsed(address maker, uint256 nonce) external view returns (bool);
function filledTakerAmount(bytes32 orderHash) external view returns (uint256);
function preApproved(bytes32 orderHash) external view returns (bool);
function remainingTakerAmount(Order calldata order) external view returns (uint256);

function preApprove(Order calldata order) external;
function invalidateNonce(uint256 nonce) external;
function invalidateNonces(uint256 wordPos, uint256 mask) external;

function fill(Order calldata order, bytes calldata signature, uint256 takerFillAmount)
    external
    returns (uint256 makerFillAmount);
```

## Rules

### Nonce bitmap

- Nonce `n` of a maker is bit `n & 0xff` of `nonceBitmap[maker][n >> 8]`.
- `invalidateNonce(n)` sets that bit for `msg.sender`. `invalidateNonces(wordPos, mask)` ORs
  `mask` into the caller's word. Both are idempotent, affect only the caller's own bitmap and
  emit `NoncesInvalidated(maker, wordPos, mask)`.
- An order whose nonce bit is set can never be filled again.

### Pre-approval

- `preApprove(order)` reverts with `NotMaker` unless `msg.sender == order.maker`. It sets
  `preApproved[hashOrder(order)]` and emits `OrderPreApproved`.

### fill

Checks, each with its own error. The tests violate one rule at a time.

| Condition | Error |
| --- | --- |
| `makerAmount == 0` or `takerAmount == 0` | `InvalidOrder` |
| `block.timestamp > expiry` | `OrderExpired` |
| `taker != address(0)` and `taker != msg.sender` | `NotTaker` |
| the maker's nonce bit is set | `NonceUsed` |
| `takerFillAmount == 0` | `ZeroFill` |
| `takerFillAmount > takerAmount - filledTakerAmount[hash]` | `Overfill` |
| computed `makerFillAmount == 0` | `ZeroFill` |
| authorisation fails (see below) | `NotAuthorised` / `InvalidSignature` |
| a token transfer fails | `TransferFailed` |

Amounts: `makerFillAmount = takerFillAmount * makerAmount / takerAmount`, rounded down. The
maker therefore never sells at a better price than quoted; dust that is lost to rounding
stays with the maker.

Authorisation of the order digest:

1. `signature.length == 0`: the order must be pre-approved, otherwise `NotAuthorised`.
2. Otherwise, if `order.maker` has code: call
   `IERC1271(maker).isValidSignature(digest, signature)`. Anything other than a successful
   return of `0x1626ba7e` (including a revert) is `InvalidSignature`.
3. Otherwise the signature must be exactly 65 bytes laid out as `r (32) || s (32) || v (1)`,
   with `s` in the lower half of the curve order
   (`s <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0`), `v` equal to
   `27` or `28`, and `ecrecover` returning a non-zero address equal to `order.maker`.
   Any violation is `InvalidSignature`.

Effects and transfers:

- Add `takerFillAmount` to `filledTakerAmount[hash]`. When the order is completely filled,
  set the maker's nonce bit. A partial fill does not touch the bitmap, so several quotes that
  share one nonce stay fillable until one of them completes or the maker invalidates the nonce.
- Transfer `takerFillAmount` of `takerToken` from `msg.sender` to the maker, then
  `makerFillAmount` of `makerToken` from the maker to `msg.sender`, both with `transferFrom`.
  A call that reverts, or that returns `false`, is `TransferFailed`. A token that returns no
  data at all is accepted.
- State must be final before the first token call. A token that calls back into `fill` must
  not be able to fill more than the order allows.
- Emit `Filled(orderHash, maker, taker, takerFillAmount, makerFillAmount)`.

`remainingTakerAmount(order)` returns `0` when the nonce is used or the order has expired,
otherwise `takerAmount - filledTakerAmount[hash]`.

## About the Signatures in the Tests

The harness cannot sign at runtime. The tests use signatures that were generated off-chain
for the maker key `0xA11CE` against the domain of the settlement contract deployed first in
`setUp()`. Contract addresses are deterministic in the harness, and
`testDeploymentMatchesSignedDomain` tells you immediately if your `DOMAIN_SEPARATOR` is not
the standard one.

## What the Tests Check

- The digest, full and partial fills, exact balances, overfill and expiry.
- Every authorisation path, including tampered fields, a signature for another contract
  instance, the high-`s` twin of a valid signature, malformed lengths and `v` values, and
  ERC-1271 wallets that reject or revert.
- Bitmap layout across words, and that only a maker can cancel or pre-approve its own orders.
- Rounding, failed and non-standard token transfers, and a re-entrant token.

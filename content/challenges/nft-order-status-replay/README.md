# Stop Cancelled and Filled NFT Orders From Being Filled

`NftOrderBook` is a fixed-price NFT marketplace. A maker who has approved the order book for
their collection lists a token with `createOrder`. A taker pays the price in ETH with
`fillOrder`; the order book moves the token from the maker to the taker and forwards the ETH.
Makers can cancel one order (`cancelOrder`) or all their outstanding orders at once
(`cancelAllOrders`, which increments the maker's nonce).

## The bugs

`fillOrder` only checks that the order exists and that the payment matches the price.

1. A cancelled order can still be filled.
2. A filled order is never closed. Marketplace approvals are long-lived, so if the maker
   later owns the token again (bought back, returned, re-minted to them) anyone can fill the
   old order again at the old price.
3. `cancelAllOrders` has no effect, because the nonce stored in the order is never compared
   with the maker's current nonce.

## Your task

Patch `src/NftOrderBook.sol`. Keep the interface unchanged.

```solidity
enum Status { None, Open, Filled, Cancelled }

function createOrder(address nft, uint256 tokenId, uint256 price) external returns (uint256 orderId);
function cancelOrder(uint256 orderId) external;
function cancelAllOrders() external;
function fillOrder(uint256 orderId) external payable;
function orderStatus(uint256 orderId) external view returns (Status);
function nonces(address maker) external view returns (uint256);
```

### Rules

- An order is `Open` after `createOrder`, and moves to exactly one of `Filled` or `Cancelled`.
  Neither of those states can be left.
- `fillOrder` reverts with `OrderNotOpen()` unless the order is `Open` (this includes order
  ids that were never created), with `StaleNonce()` if the order was created under an older
  maker nonce, and with `WrongPrice()` if `msg.value != price`. Checks run in that order.
- `fillOrder` marks the order `Filled` before it transfers the token or pays the maker.
- `cancelOrder` is maker-only (`NotMaker()`) and reverts with `OrderNotOpen()` unless the
  order is `Open`.
- `cancelAllOrders` increments `nonces[msg.sender]`. Orders the maker creates afterwards are
  fillable; orders of other makers are unaffected.
- `createOrder` requires the caller to own the token (`NotMaker()`) and `price > 0`
  (`ZeroPrice()`).

## What the tests check

- A normal sale moves the token and pays the maker.
- Filling after `cancelOrder` or after `cancelAllOrders` reverts.
- A filled order cannot be filled again after the token returns to the maker.
- Status transitions, access control and the listed revert reasons.

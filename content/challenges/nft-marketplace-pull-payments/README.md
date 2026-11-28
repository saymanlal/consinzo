# NFT Marketplace with Protocol Fee and Pull Payments

## Problem Statement

Implement `NftMarketplace` in `src/NftMarketplace.sol`: a fixed-price marketplace for
ERC-721 tokens. Sellers escrow a token in the marketplace when they list it. A buyer pays
in ETH; the marketplace keeps a protocol fee and credits the rest to the seller. No ETH is
ever pushed to a seller, the fee recipient or an overpaying buyer during a trade. Every
party collects what it is owed with `withdraw()` (the pull-payment pattern), so a
recipient that rejects ETH cannot block a sale.

The marketplace talks to NFT contracts through the `IERC721` subset declared in the same
file. The tests use a mock ERC-721.

## Interface

```solidity
uint16 public constant MAX_FEE_BPS = 1000; // 10%

constructor(uint16 feeBps_, address feeRecipient_)

function owner() external view returns (address);
function feeBps() external view returns (uint16);
function feeRecipient() external view returns (address);
function listingCount() external view returns (uint256);
function listings(uint256 id) external view returns (
    address seller, address nft, uint256 tokenId, uint256 price, uint16 feeBps, bool active
);
function pendingWithdrawals(address account) external view returns (uint256);
function totalPending() external view returns (uint256);

function setFee(uint16 newFeeBps, address newFeeRecipient) external;
function list(address nft, uint256 tokenId, uint256 price) external returns (uint256 listingId);
function updatePrice(uint256 listingId, uint256 newPrice) external;
function cancel(uint256 listingId) external;
function buy(uint256 listingId) external payable;
function withdraw() external;

event Listed(uint256 indexed listingId, address indexed seller, address indexed nft, uint256 tokenId, uint256 price);
event PriceUpdated(uint256 indexed listingId, uint256 newPrice);
event Cancelled(uint256 indexed listingId);
event Sold(uint256 indexed listingId, address indexed buyer, uint256 price, uint256 fee);
event Withdrawn(address indexed account, uint256 amount);
event FeeUpdated(uint16 feeBps, address feeRecipient);

error NotOwner();
error ZeroAddress();
error FeeTooHigh();
error ZeroPrice();
error NotTokenOwner();
error ListingNotActive();
error NotSeller();
error SelfPurchase();
error InsufficientPayment();
error NothingToWithdraw();
error TransferFailed();
```

## Rules

### Configuration

1. The deployer is `owner`. The constructor and `setFee` revert with `FeeTooHigh()` when
   the fee exceeds `MAX_FEE_BPS` and with `ZeroAddress()` when the recipient is
   `address(0)` (fee check first). `setFee` is owner-only (`NotOwner()`, checked first).

### Listing

2. `list` checks, in order: `nft != address(0)` (`ZeroAddress()`), `price != 0`
   (`ZeroPrice()`), `IERC721(nft).ownerOf(tokenId) == msg.sender` (`NotTokenOwner()`). It
   then moves the token into the marketplace with
   `transferFrom(msg.sender, address(this), tokenId)`; the seller must have approved the
   marketplace beforehand. Listing ids start at 1.
3. A listing records the **fee rate in force when it was created**. Later `setFee` calls
   do not change the fee of existing listings.
4. `updatePrice` and `cancel` revert with `ListingNotActive()` if the listing does not
   exist, was sold or was cancelled, and otherwise with `NotSeller()` if the caller is not
   the seller. `updatePrice` reverts with `ZeroPrice()` for a zero price (checked last).
   `cancel` deactivates the listing and returns the token to the seller.

### Buying

5. `buy` checks, in order: the listing is active (`ListingNotActive()`), the caller is not
   the seller (`SelfPurchase()`), `msg.value >= price` (`InsufficientPayment()`).
6. On success:
   - `fee = price * listing.feeBps / 10_000`, rounded down;
   - `pendingWithdrawals[feeRecipient] += fee` (the recipient configured at purchase time);
   - `pendingWithdrawals[seller] += price - fee`;
   - `pendingWithdrawals[buyer] += msg.value - price` (the overpayment);
   - the listing becomes inactive and the token is transferred to the buyer.
   The listing must be inactive before the token contract is called.

### Withdrawing

7. `withdraw()` sends the caller their whole pending amount. It reverts with
   `NothingToWithdraw()` when the amount is zero and with `TransferFailed()` when the ETH
   transfer fails. The balance must be cleared before ETH is sent.
8. `totalPending` is the sum of all pending withdrawals and must always equal the ETH
   balance of the marketplace (ignoring ETH forced into it).

## What the tests check

- The listing lifecycle: escrow, price updates, cancellation and purchase.
- Fee arithmetic, fee snapshots and fee-recipient changes.
- Pull payments: credits for seller, fee recipient and overpaying buyer; reentrancy on
  `withdraw`; recipients that reject ETH.
- Access control and every revert condition above.
- `address(marketplace).balance == totalPending()` across sequences of trades.

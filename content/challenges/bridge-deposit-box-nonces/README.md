# Bridge Deposit Box with Per-Destination Nonces

## Problem Statement

The source side of a token bridge is a contract that takes custody of tokens and leaves a
record that off-chain relayers can carry to the destination chain. Each record must be
uniquely identifiable so that the destination can process every deposit exactly once and,
if it wants to, in order.

Implement `BridgeDepositBox` in `src/BridgeDepositBox.sol`. It locks one ERC-20 token and
numbers deposits with a separate counter for every destination chain.

The token used by the tests is a mock written inside the test files. Destination chains are
plain chain-id numbers; nothing is sent anywhere.

## Interface

```solidity
constructor(address token_)

function owner() external view returns (address);   // the deployer
function token() external view returns (IERC20);
function supportedChain(uint256 chainId) external view returns (bool);
function nextNonce(uint256 destChainId) external view returns (uint256);
function lockedFor(uint256 destChainId) external view returns (uint256);
function totalLocked() external view returns (uint256);

function deposits(uint256 destChainId, uint256 nonce)
    external view returns (address depositor, address recipient, uint256 amount);

function setChainSupported(uint256 chainId, bool supported) external;
function deposit(uint256 destChainId, address recipient, uint256 amount) external returns (uint256 nonce);
function depositHash(uint256 destChainId, uint256 nonce) external view returns (bytes32);

error ZeroAddress();
error NotOwner();
error SameChain();
error UnsupportedChain(uint256 chainId);
error ZeroAmount();
error TransferFailed();
error UnknownDeposit();

event ChainSupportUpdated(uint256 indexed chainId, bool supported);
event Deposited(
    uint256 indexed destChainId, uint256 indexed nonce,
    address indexed depositor, address recipient, uint256 amount
);
```

## Rules

1. The constructor reverts with `ZeroAddress()` when `token_` is zero.
2. `setChainSupported` is owner-only (`NotOwner()`). The chain the box is deployed on
   (`block.chainid`) can never be a destination: passing it reverts with `SameChain()`.
   Disabling a chain does not reset its nonce or its deposit records.
3. `deposit` checks, in this order:
   - `UnsupportedChain(destChainId)` if the destination is not enabled;
   - `ZeroAddress()` if `recipient` is zero;
   - `ZeroAmount()` if `amount` is zero.
4. A successful `deposit`:
   - uses `nextNonce[destChainId]` as the nonce and then increments it. Nonces start at 0
     and are independent per destination chain;
   - stores `(msg.sender, recipient, amount)` under `(destChainId, nonce)`;
   - increases `lockedFor[destChainId]` and `totalLocked` by `amount`;
   - pulls `amount` from the caller with `token.transferFrom(msg.sender, address(this), amount)`.
     If the token returns `false` the call reverts with `TransferFailed()`;
   - returns the nonce.
5. `depositHash(destChainId, nonce)` reverts with `UnknownDeposit()` for a nonce that has
   not been used on that destination. Otherwise it returns the identifier a relayer would
   attest to:

   ```solidity
   keccak256(abi.encode(
       block.chainid, address(this), destChainId, nonce, depositor, recipient, amount
   ))
   ```
6. There is no withdrawal function. Tokens stay locked.

## What the tests check

- Nonces per destination, record contents and accounting.
- The revert conditions and their order.
- A token that returns `false` from `transferFrom`.
- That `depositHash` matches the formula and differs between deposits.

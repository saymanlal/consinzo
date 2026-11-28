# Uninitialised implementation contracts

## How upgradeable proxies split responsibilities

- The **proxy** holds state and ETH. It stores the implementation address in the ERC-1967
  slot `bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)` and forwards calls
  with `delegatecall`.
- The **implementation** holds code. In the UUPS pattern (ERC-1822) the upgrade function is
  part of the implementation and writes the slot in the proxy's storage.

Because constructors do not run for proxies, implementations expose an `initialize`
function, guarded so that it runs once *per storage context*.

## The forgotten storage context

The implementation is itself a deployed contract. In its own storage the "run once" flag is
unset, so `initialize` can be called there by anyone. Whether that matters depends on what
an initialised implementation lets its owner do. With UUPS the answer is: reach a
`delegatecall` to a chosen address. Combined with `SELFDESTRUCT`, this allowed destroying
the logic contract of live proxies, which cannot be repaired because the upgrade code was
in the destroyed contract.

## Standard mitigations

1. **Disable initialisers in the constructor** of every implementation. The constructor
   runs in the implementation's storage only.
2. **`onlyProxy` guard** on upgrade functions: store `address(this)` in an immutable and
   require `address(this) != __self`. Optionally also check that the proxy's ERC-1967 slot
   points at `__self`.
3. Deploy and initialise proxies atomically (constructor calldata), never in two
   transactions.

## EIP-6780

Since the Cancun upgrade, `SELFDESTRUCT` only deletes a contract when called in the same
transaction that created it. This removes the most destructive outcome on networks that
have adopted it. It does not remove the takeover: code running as the implementation can
still move assets the implementation holds and abuse any trust placed in its address.

## Review checklist

- Does every implementation have a constructor that locks initialisation?
- Can any function containing `delegatecall` or `selfdestruct` be reached directly?
- Do upgraded versions inherit the same guards?

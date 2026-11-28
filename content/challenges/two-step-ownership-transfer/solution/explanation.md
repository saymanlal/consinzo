# Reference Solution Explanation

- **Separation of proposal and transfer**: `proposeOwner` writes only `pendingOwner`. Authority
  moves in `acceptOwnership`, which must be called from the candidate address. A mistyped or
  uncontrolled address can never complete the transfer, and the owner can correct the mistake by
  proposing again or cancelling.
- **`onlyOwner` modifier**: the owner check is written once and placed first on both owner
  functions, which gives the required check order (caller, then arguments or state).
- **Accept check**: `msg.sender != pendingOwner` covers both a wrong caller and the case where
  nothing is pending, because `msg.sender` is never the zero address.
- **Clearing `pendingOwner`**: done on acceptance and on cancellation. If it were left set after
  acceptance, the same address could call `acceptOwnership` again later and take the contract back
  from a subsequent owner.

## Pitfalls

- Changing `owner` inside `proposeOwner`.
- Letting the current owner call `acceptOwnership` on behalf of the candidate.
- Forgetting to clear `pendingOwner`, which the replay test catches.
- Checking `candidate == address(0)` before the caller, which reports the wrong error to
  non-owners.

# Solution Explanation: NEAR Storage Registration

1. **Registration is a recorded payment.** The `storagePaid` map stores, per account, the fee that was charged when the account registered. Presence of the key is the registration flag; the value is the refund owed on exit.
2. **Refund what was paid.** `unregister` returns the recorded value, not `this.storageFee`. If the fee has been raised since, refunding the current fee would pay out more than was collected and drain other users' deposits; if it has been lowered, the user would lose money.
3. **Excess deposits.** Only the fee becomes storage balance. The difference is credited to the refundable balance immediately, so over-paying is harmless.
4. **Pull payments.** All outgoing amounts accumulate in `refundable` and leave through `claimRefund`, which zeroes the balance before returning the amount. A claim does not depend on being registered, so refunds remain collectable after unregistering.
5. **Unregister releases storage.** The note is deleted along with the registration. Otherwise the account would get its fee back while the contract kept paying for its data, and a re-registration would resurrect old data.
6. **`totalStorageHeld`** moves by the recorded fee on register and unregister, so it always equals the sum of the recorded balances.

## Pitfalls
- Refunding the current fee instead of the recorded one.
- Keeping the whole attached deposit as storage balance, or silently discarding the excess.
- Leaving the note in storage after unregistering.
- Allowing a second `register` call to overwrite the record (and double-count the total).

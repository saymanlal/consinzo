# Background: allowlists

- An allowlist is a set of accounts permitted to call some method. On NEAR it is usually a `LookupMap` (or `LookupSet`) keyed by account id, checked against `near.predecessorAccountId()`.
- `LookupMap` has no size or iteration. Keep a counter if you need to know how many members exist.
- Storage on NEAR is paid for by the contract's balance, so removing keys that are no longer needed is good practice.
- Role checks belong at the very top of a method. Code that runs before the check can leak information or do work on behalf of an unauthorised caller.

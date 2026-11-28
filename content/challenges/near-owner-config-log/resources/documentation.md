# Background: ownership and audit logs

- A NEAR contract has no built-in owner. The common pattern is to store the deploying or initialising account and compare `near.predecessorAccountId()` with it in privileged methods.
- `near.predecessorAccountId()` is the immediate caller. It is the right identity for access control because it cannot be borrowed through an intermediate contract.
- An append-only log is a list that is only ever extended. With `LookupMap` it is built from a length counter and entries stored under their index.
- Recording the old value with each change lets off-chain tools reconstruct the full history without reading past state.

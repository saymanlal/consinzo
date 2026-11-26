# Signer vs Predecessor Security Notes

- Always check `near.predecessorAccountId()` for balance ownership and privileged governance methods.
- `near.signerAccountId()` should only be used as a gas-payer or off-chain UX hint, never for authorization.

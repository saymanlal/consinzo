# Protecting configuration and upgrade methods on NEAR

## Every method is public
A method exported by a NEAR contract can be called by any account. There is no visibility modifier that restricts callers; restrictions are checks written in the method body (or the `private` decorator, which only allows the contract itself).

## Authorising the caller
- `near.predecessorAccountId()`: the account that directly called this method.
- `near.signerAccountId()`: the account that signed the transaction that started the call chain.
- `near.currentAccountId()`: the contract's own account.

Owner checks compare the predecessor with a stored owner account. Checks against the signer are equivalent to `tx.origin` checks on Ethereum and are bypassed by any intermediate contract.

## What counts as privileged
Any method that changes who gets paid, how much is charged, who the owner is, which code runs, or whether the contract is paused. Audit by listing every state variable that represents authority or policy and then every method that writes it.

## Defence in depth for configuration
- Bound numeric parameters (maximum fee, minimum delay).
- Reject empty or obviously invalid account ids.
- Consider two-step ownership transfer and a time delay for sensitive changes.
- Emit a log for every configuration change so monitoring can alert on it.

## Contract upgrades
Deploying new code to a contract account is the most privileged operation of all. Contracts that upgrade themselves through a method must protect that method in the same way as described here.

# Background: allowances and delegated transfers

- An allowance lets a third party (the spender) move a limited amount of an owner's tokens. It is the mechanism behind "approve, then let a contract pull the tokens".
- NEAR's NEP-141 standard does not include allowances; it uses `ft_transfer_call`, where the owner pushes tokens to a contract and the contract reacts in `ft_on_transfer`. Allowances are still widely used in bridged and EVM-style token designs, and the bookkeeping is a standard exercise.
- Three accounts are involved in a delegated transfer: the owner (source of the tokens), the spender (the caller, checked against the allowance) and the receiver (destination). Keeping these roles apart is the main difficulty.
- Composite keys are the usual way to store a two-dimensional mapping in a flat key-value store such as NEAR contract storage.

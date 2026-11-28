# Background: fungible tokens on NEAR

- NEAR's fungible token standard is NEP-141. Its core methods are `ft_transfer`, `ft_transfer_call`, `ft_total_supply` and `ft_balance_of`. Unlike native NEAR, token balances live inside the token contract's own storage as a mapping from account id to amount.
- Amounts are unsigned 128-bit integers in the standard and are passed as strings in JSON. In TypeScript they are handled as `bigint`. Because `bigint` is signed, the contract must reject non-positive amounts explicitly.
- The central invariant of any token is that the total supply equals the sum of all balances. Every method should be checked against it.
- This exercise leaves out storage registration, the one-yocto security deposit and cross-contract `ft_transfer_call`; it covers the balance accounting those features are built on.

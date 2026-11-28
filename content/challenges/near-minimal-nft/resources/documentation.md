# Background: non-fungible tokens on NEAR

- NEAR's NFT standard is NEP-171. Each token has a string `token_id` that is unique within the contract and exactly one owner. The core methods are `nft_transfer`, `nft_transfer_call` and `nft_token`.
- Enumeration (listing tokens per owner, supply) is an optional extension (NEP-181). Contracts that support it keep additional indexes next to the ownership map; the per-account balance in this exercise is the simplest such index.
- Minting is not part of the standard. Each contract decides who may mint; a fixed minter account is the most common starting point.
- This exercise leaves out approvals, metadata, storage deposits and cross-contract transfer calls and concentrates on ownership bookkeeping.

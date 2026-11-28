# Background: storage staking and registration on NEAR

- NEAR charges for storage by requiring the contract account to keep a balance proportional to the bytes it stores ("storage staking"). If users can make a contract store data for free, they can lock up the contract's funds.
- The usual defence is to make each user cover the storage they cause. NEP-145 (storage management) standardises this for token contracts: `storage_deposit` registers an account by paying a fee, `storage_unregister` removes it and refunds the fee, and `storage_balance_of` reports what is held.
- The contract must remember how much each account paid. Refunds are based on that record, and the data the fee covered must be deleted when the fee is returned.
- In a deployed contract refunds are sent with a transfer action. In this exercise they are tracked as claimable balances, which is also a robust pattern in production: the state change and the payout are separate, explicit steps.

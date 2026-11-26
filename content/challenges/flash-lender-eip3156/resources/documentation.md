# EIP-3156 Flash Loan Provider

Verifies the EIP-3156 callback magic hash, pulls `amount + fee` via `transferFrom`, and asserts post-loan balance >= `beforeBal + fee`.

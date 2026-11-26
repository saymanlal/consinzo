# Patch tx.origin Phishing Vulnerability

`OriginWallet` authorizes transfers using `tx.origin == owner`, allowing any contract tricked into being called by `owner` to drain the wallet.

## Objective
Replace `tx.origin` with `msg.sender` and preserve legitimate owner transfers.
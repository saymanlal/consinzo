# Handle Fee-on-Transfer Tokens via Balance Delta Accounting

Computes `received = token.balanceOf(address(this)) - beforeBal` so internal ledger balances always match held tokens.

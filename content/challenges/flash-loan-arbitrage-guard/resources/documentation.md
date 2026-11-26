# Vault Accounting Security Reference
Never derive share exchange rates directly from `address(this).balance` or `ERC20.balanceOf(address(this))` without accounting for unsolicited transfers.

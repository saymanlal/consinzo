# Defend a Vault Against Donation & Share Inflation Attacks

`ShareVault` currently reads `address(this).balance` when pricing shares. An attacker can deposit 1 wei, donate ETH directly via a `receive()` fallback or `selfdestruct`, and cause a victim's deposit to round down to 0 shares.

## Objective
Track managed assets internally (`totalManagedAssets`) and revert if `sharesMinted == 0`.

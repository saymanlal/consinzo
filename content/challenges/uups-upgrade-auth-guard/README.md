# Exploit Unprotected Upgradeable Implementation

`VulnerableUpgradeable` exposes `upgradeTo(address)` without `onlyOwner` and delegates calls to `implementation`.

## Objective
Implement `UpgradeExploit.attack(address target)` to upgrade `target` to `address(this)` and drain its ETH.
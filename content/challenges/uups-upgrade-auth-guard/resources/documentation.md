# Exploit Unprotected Upgradeable Implementation

Calls unprotected `upgradeTo(address(this))` and triggers `execute` with `drain(...)` via `delegatecall` so the proxy transfers its own balance to the attacker.

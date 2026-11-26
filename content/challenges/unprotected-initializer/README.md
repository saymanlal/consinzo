# Exploit Unprotected Proxy Initializer

`TargetVault` exposes `initialize(address _owner)` without an `initialized` guard.

## Objective
Implement `Exploit.pwn(address target)` in `src/Exploit.sol` to claim ownership and sweep all ETH out of `TargetVault` into `address(this)`.
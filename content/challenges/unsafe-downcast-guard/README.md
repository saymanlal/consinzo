# Prevent Silent Integer Truncation on Unsafe Downcast

`PackedStake.deposit(uint256 amount)` packs `uint96(amount)` alongside a timestamp, silently wrapping values `> type(uint96).max`.

## Objective
Require `amount <= type(uint96).max` before casting.
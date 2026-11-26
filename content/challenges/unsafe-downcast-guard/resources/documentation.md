# Prevent Silent Integer Truncation on Unsafe Downcast

Enforces `amount <= type(uint96).max` before narrowing from `uint256` to `uint96`, matching OpenZeppelin `SafeCast.toUint96` semantics.

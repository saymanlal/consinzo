# ERC-20 Engineering Notes

- EIP-20 requires `Transfer` events on mint (`from = address(0)`) and burn (`to = address(0)`).
- Always guard against `address(0)` recipients and spenders unless deliberately burning.

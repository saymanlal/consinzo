# Gas-Efficient 256-Bit Bitmap Whitelist Registry

Implement `setFlag(uint256 index)`, `clearFlag(uint256 index)`, and `hasFlag(uint256 index)` packing 256 bits per `uint256` word (`word = index >> 8`, `bit = index & 0xff`).
# Gas-Efficient 256-Bit Bitmap Whitelist Registry

Packs 256 flags into each `uint256` word using `index >> 8` bucket addressing and `1 << (index & 0xff)` bitmasks.

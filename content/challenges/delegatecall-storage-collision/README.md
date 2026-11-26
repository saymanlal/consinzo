# Fix Delegatecall Storage Slot Collision

`SafeProxy` puts `implementation` in slot 0 and `owner` in slot 1, while `LogicV1` writes `lastNumber` into slot 0—allowing any user calling `executeNumber` to overwrite `implementation`.

## Objective
Align the storage layout and restrict direct untrusted `delegatecall` surfaces.
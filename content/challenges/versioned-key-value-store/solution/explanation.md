# Reference Solution Explanation

Each key has an `Entry { uint64 version; bool live; }` and a history mapping
`key => version => bytes`.

- `set` compares `expectedVersion` with the stored version, then writes the value under
  `version + 1`. Storing values per version gives `valueAt` for free; the current value is
  simply the history entry at the current version.
- `remove` runs the same comparison first and only then checks `live`. The order matters:
  a caller with a stale version should learn that its view is stale (`VersionMismatch`),
  not that the key is missing.
- `remove` increases the version and clears `live`. It writes nothing to the history, so
  `valueAt` returns empty bytes for that version.
- `get` returns the history entry only while the key is live.

## Pitfalls

- Resetting the version to zero on removal. A writer that read the key before it was ever
  written could then overwrite a key that has been set and removed in the meantime (the
  classic ABA problem).
- Deriving existence from `value.length != 0`. An empty value is a legal value and must
  remain removable and readable as "exists".
- Accepting `expectedVersion <= current`. The comparison must be an equality.
- Letting `valueAt` return empty bytes for versions that were never created instead of
  reverting with `UnknownVersion`.

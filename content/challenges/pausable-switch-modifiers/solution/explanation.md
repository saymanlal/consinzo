# Reference Solution Explanation

- **Three small modifiers**: `onlyOwner`, `whenNotPaused` and `whenPaused` each test one condition
  and revert with one error. Functions state their requirements in their signature, which is easier
  to review than checks scattered through bodies.
- **Modifier order**: modifiers execute in the order they are listed. `onlyOwner` is first on
  `pause`, `unpause` and `emergencyReset`, so a non-owner gets `NotOwner` even when the pause check
  would fail too.
- **The switch guards itself**: `pause` carries `whenNotPaused` and `unpause` carries `whenPaused`.
  That makes redundant calls revert, so the `Paused`/`Unpaused` events always describe a real state
  change.
- **Opposite guards**: `ping` and `emergencyReset` are never callable in the same state. This is
  the usual shape of an emergency mechanism: normal operation stops before recovery functions
  become available.

## Pitfalls

- Declaring the modifiers but forgetting to attach them to the functions.
- Omitting `_;`, which makes the function body never run.
- Swapping the two errors: `EnforcedPause` means "this needs the contract running",
  `ExpectedPause` means "this needs the contract paused".
- Listing the pause modifier before `onlyOwner`.

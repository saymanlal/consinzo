# Why the patch works

A TWAP is `(cumulative(now) - cumulative(then)) / (now - then)`. Its resistance to
manipulation comes entirely from the length of `now - then`: holding the spot price at
`k` times its true value for `d` seconds moves the average by a factor of about
`1 + (k - 1) * d / window`.

In the starter the attacker controls `then`. `update()` overwrites the only observation, so
calling it immediately before the manipulation makes the window one block long and the
"average" equals the manipulated spot price.

The reference makes the window a property the oracle enforces.

- **Ring buffer.** Twelve observations are kept; observation `n` lives at index `n % 12`.
- **Spacing.** `update()` records only when the newest observation is at least five minutes
  old. Twelve stored observations therefore span at least 55 minutes. Calling `update()` in
  a loop cannot push old observations out.
- **Minimum window.** `consult()` walks backwards from the newest observation and uses the
  first one that is at least thirty minutes old. If there is none it reverts.

With an hour of history and a 100x pump held for 12 seconds, the reference reports
`(1800 * 1 + 12 * 100) / 1812`, about 1.66.

## Pitfalls

- Reverting in `update()` when called too early breaks keepers and integrations that call
  it opportunistically. Return `false` instead.
- Adding a time check to `consult()` while keeping one observation turns the bug into a
  denial of service: any caller of `update()` makes the oracle unusable for thirty minutes.
- Using the *oldest* stored observation is safe but needlessly stale. The newest one that
  satisfies the window gives the freshest valid average.
- The spacing rule is what guarantees coverage. Without it, cardinality alone does not help.

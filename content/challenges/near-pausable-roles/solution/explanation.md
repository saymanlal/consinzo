# Solution Explanation: NEAR Pausable Ledger

1. **Asymmetric roles.** Pausing limits damage and should be easy to trigger, so both the admin and a dedicated pauser may do it. Unpausing re-exposes the contract and is reserved for the admin. A compromised pauser key can therefore stop deposits but cannot restart them or change roles.
2. **Role check, then state check.** `pause` and `unpause` first establish that the caller is allowed to act and only then look at the `paused` flag. An outsider always receives the role error.
3. **Scope of the pause.** `deposit` is gated by `paused`; `withdraw` is not. An emergency stop that also blocked withdrawals would let the admin freeze user funds indefinitely.
4. **Unset pauser.** The pauser is stored as `""` when absent. The comparison explicitly requires a non-empty pauser so that the "no pauser" state can never authorise anyone.
5. **Admin handover.** Every admin check reads the stored field, so replacing it revokes the previous admin immediately. The old admin is not the pauser either, so it can no longer pause.

## Pitfalls
- Allowing the pauser to unpause.
- Adding the pause check to `withdraw`.
- Checking `paused` before the caller's role, which reports `Already paused` to unauthorised callers.

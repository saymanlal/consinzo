# Background: emergency stops and role separation

- A pausable contract has a flag that disables selected entry points. It is used to contain damage while a problem is investigated.
- Good designs separate the *pause* permission from the *unpause* permission. Pausing is low risk and may be delegated to a monitoring key; unpausing and role management stay with a more protected account.
- Which methods a pause covers is a design decision. Blocking new deposits while keeping withdrawals open protects new funds without holding existing users hostage.
- On NEAR all role checks should use `near.predecessorAccountId()`. Roles are plain values in contract state; the contract itself must compare them on every privileged call.

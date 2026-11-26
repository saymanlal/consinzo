# DAO Governance Invariants

- **One Vote Per Member Per Proposal**: Prevent Sybil replay or vote amplification by tracking composite receipt keys.
- **Time-Bounded Windows**: Reject late votes cleanly and block premature finalization before voting closes.

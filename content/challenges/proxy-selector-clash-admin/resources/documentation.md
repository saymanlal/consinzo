# Function selector clashes in upgradeable proxies

## Selectors

A call's first four bytes are `bytes4(keccak256("name(type1,type2)"))`. Four bytes give about
4.3 billion values, so unrelated signatures collide regularly. Finding a signature that
collides with a chosen selector takes seconds on a laptop. A well-known pair:

| Signature | Selector |
| --- | --- |
| `burn(uint256)` | `0x42966c68` |
| `collate_propagate_storage(bytes16)` | `0x42966c68` |

Within one contract the compiler rejects clashing selectors. Across a proxy and its
implementation nothing checks, because they are compiled separately.

## How a proxy dispatches

A proxy written in Solidity gets the standard dispatcher: match the selector against the
proxy's own external functions, otherwise run `fallback()`, which delegates. So the proxy's
functions win every clash. If such a function changes proxy state, a user who intends to
call the implementation changes the proxy instead. A proxy author can hide a backdoor this
way: the function name looks harmless and the trigger is a routine user action.

## The transparent proxy rule

Route on the caller, not the selector:

- the admin can call only the proxy's management functions and is never forwarded;
- everybody else is always forwarded.

To make the second half hold for every selector, the proxy must not declare external
functions; the admin interface is decoded inside `fallback()`.

The alternative design, UUPS, puts the upgrade function in the implementation, where the
compiler does detect clashes, and leaves the proxy with a bare fallback.

## EIP-1967 slots

Proxy state is kept in fixed pseudo-random slots (`keccak256("eip1967.proxy.implementation") - 1`
and `keccak256("eip1967.proxy.admin") - 1`) so that it cannot overlap the implementation's
sequential storage layout.

## Review checklist

- List every external and public function of the proxy with its selector.
- Compare against every selector of every implementation version.
- Prefer proxies with no external functions besides `fallback` and `receive`.

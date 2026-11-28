# Solution Explanation: NEAR Status Message

1. **Configurable limit.** The constructor validates and stores `maxLength`. `setStatus` compares against the stored value, so the same code serves any limit and the boundary (`length === maxLength`) is accepted.
2. **Validation before effects.** Both length checks run before the map or the counters are touched. A rejected call therefore leaves the previous status and both counters exactly as they were.
3. **Status and counter are independent.** The message map answers "what is the status now"; the counter map answers "how many times was it set". `clearStatus` removes only the message, so the counter keeps growing across clears.
4. **Counting updates, not changes.** The counter increments on every successful `setStatus`, even when the text is identical, which is what the specification asks for.

## Pitfalls
- Hard-coding 64 instead of using the constructor argument.
- Using `<` instead of `<=` at the length boundary.
- Resetting the counter in `clearStatus`, or counting a clear as an update.
- Storing an empty string to represent "cleared", which makes `getStatus` return `""` instead of `null`.

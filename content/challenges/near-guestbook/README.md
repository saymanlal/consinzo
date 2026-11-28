# NEAR Guestbook with Latest Messages

## Objective
Implement `Guestbook` in `src/Guestbook.ts`. Visitors append short messages; each message records who wrote it and when. Readers fetch a single message by index or the latest N messages.

## Interface

```ts
export interface GuestMessage {
  index: number;      // position in the log, starting at 0
  sender: string;     // near.predecessorAccountId() at the time of the call
  text: string;
  timestamp: bigint;  // near.blockTimestamp() at the time of the call
}

addMessage(text: string): number
getMessage(index: number): GuestMessage | null
totalMessages(): number
latest(n: number): GuestMessage[]
```

## Rules
1. `addMessage(text)` requires `1 <= text.length <= 280`, otherwise it throws an error containing `Invalid message length`. It stores the message and returns its index. Indices are assigned in order: 0, 1, 2, ...
2. `getMessage(index)` returns the stored message, or `null` when no message has that index.
3. `totalMessages()` returns how many messages were stored.
4. `latest(n)` returns at most `n` messages, newest first. If fewer than `n` messages exist it returns all of them. `n` must be a non-negative integer, otherwise it throws an error containing `Invalid count`. `latest(0)` returns an empty array.
5. A rejected `addMessage` must not change any state.

## What the tests check
Index assignment, recorded sender and timestamp, ordering and truncation of `latest`, the length boundaries (0, 1, 280, 281 characters) and invalid counts.

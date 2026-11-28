import { LookupMap, near, assert } from "near-sdk-js";

export interface GuestMessage {
  index: number;
  sender: string;
  text: string;
  timestamp: bigint;
}

export const MAX_MESSAGE_LENGTH = 280;

export class Guestbook {
  private messages = new LookupMap<GuestMessage>("msg:");
  private count = 0;

  addMessage(text: string): number {
    assert(text.length >= 1 && text.length <= MAX_MESSAGE_LENGTH, "Invalid message length");
    const index = this.count;
    this.messages.set(String(index), {
      index,
      sender: near.predecessorAccountId(),
      text,
      timestamp: near.blockTimestamp(),
    });
    this.count = index + 1;
    return index;
  }

  getMessage(index: number): GuestMessage | null {
    return this.messages.get(String(index));
  }

  totalMessages(): number {
    return this.count;
  }

  latest(n: number): GuestMessage[] {
    assert(Number.isInteger(n) && n >= 0, "Invalid count");
    const out: GuestMessage[] = [];
    // Walk from the newest index downwards; LookupMap has no iteration, so the counter drives the loop.
    for (let i = this.count - 1; i >= 0 && out.length < n; i--) {
      const message = this.messages.get(String(i));
      if (message !== null) out.push(message);
    }
    return out;
  }
}

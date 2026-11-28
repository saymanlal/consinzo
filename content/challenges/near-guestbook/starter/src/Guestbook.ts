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
    // TODO: validate 1 <= text.length <= MAX_MESSAGE_LENGTH ("Invalid message length"), store the message under the next index with sender and timestamp, return the index
    throw new Error("Not implemented");
  }

  getMessage(index: number): GuestMessage | null {
    return this.messages.get(String(index));
  }

  totalMessages(): number {
    return this.count;
  }

  latest(n: number): GuestMessage[] {
    // TODO: require a non-negative integer n ("Invalid count") and return up to n messages, newest first
    throw new Error("Not implemented");
  }
}

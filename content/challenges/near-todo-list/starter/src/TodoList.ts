import { LookupMap, near, assert } from "near-sdk-js";

export interface Task {
  id: number;
  title: string;
  done: boolean;
}

export const MAX_TITLE_LENGTH = 100;

export class TodoList {
  private tasks = new LookupMap<Task>("task:");
  private counts = new LookupMap<number>("count:");
  private pending = new LookupMap<number>("pending:");

  private key(account: string, id: number): string {
    return account + ":" + String(id);
  }

  addTask(title: string): number {
    // TODO: validate the title ("Invalid title"), store a new task for the caller under the next id, update the counters, return the id
    throw new Error("Not implemented");
  }

  completeTask(id: number): void {
    // TODO: load the caller's task ("Task not found"), reject a done task ("Already completed"), mark it done and update the pending counter
    throw new Error("Not implemented");
  }

  getTask(account: string, id: number): Task | null {
    return this.tasks.get(this.key(account, id));
  }

  taskCount(account: string): number {
    return this.counts.get(account) ?? 0;
  }

  pendingCount(account: string): number {
    return this.pending.get(account) ?? 0;
  }

  listTasks(account: string): Task[] {
    // TODO: return every task of the account ordered by id
    throw new Error("Not implemented");
  }
}

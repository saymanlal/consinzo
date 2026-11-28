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
    assert(title.length >= 1 && title.length <= MAX_TITLE_LENGTH, "Invalid title");
    const caller = near.predecessorAccountId();
    const id = this.counts.get(caller) ?? 0;
    this.tasks.set(this.key(caller, id), { id, title, done: false });
    this.counts.set(caller, id + 1);
    this.pending.set(caller, (this.pending.get(caller) ?? 0) + 1);
    return id;
  }

  completeTask(id: number): void {
    const caller = near.predecessorAccountId();
    const task = this.tasks.get(this.key(caller, id));
    if (task === null) throw new Error("Task not found");
    assert(!task.done, "Already completed");
    this.tasks.set(this.key(caller, id), { ...task, done: true });
    this.pending.set(caller, (this.pending.get(caller) ?? 0) - 1);
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
    const out: Task[] = [];
    const count = this.taskCount(account);
    for (let id = 0; id < count; id++) {
      const task = this.tasks.get(this.key(account, id));
      if (task !== null) out.push(task);
    }
    return out;
  }
}

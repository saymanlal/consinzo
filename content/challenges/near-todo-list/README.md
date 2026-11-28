# NEAR Per-Account Todo List

## Objective
Implement `TodoList` in `src/TodoList.ts`. Each account has its own list. Task ids are per account and start at 0.

## Interface

```ts
export interface Task {
  id: number;
  title: string;
  done: boolean;
}

addTask(title: string): number
completeTask(id: number): void
getTask(account: string, id: number): Task | null
taskCount(account: string): number
pendingCount(account: string): number
listTasks(account: string): Task[]
```

## Rules
1. `addTask(title)` adds a task to the list of `near.predecessorAccountId()`.
   - `title.length` must be between 1 and 100, otherwise throw an error containing `Invalid title`.
   - The new task has `done = false` and the next free id for that account (0, 1, 2, ...). The id is returned.
2. `completeTask(id)` marks one of the caller's own tasks as done.
   - If the caller has no task with that id, throw an error containing `Task not found`.
   - If the task is already done, throw an error containing `Already completed`.
3. `getTask(account, id)` returns the task or `null`.
4. `taskCount(account)` returns how many tasks the account has added.
5. `pendingCount(account)` returns how many of them are not done yet.
6. `listTasks(account)` returns all tasks of the account ordered by id (an empty array for an unknown account).
7. Accounts cannot see their ids collide: Alice's task 0 and Bob's task 0 are different tasks.

## What the tests check
Id assignment per account, completing tasks, the two error cases of `completeTask`, isolation between accounts, pending counts and the title length boundaries.

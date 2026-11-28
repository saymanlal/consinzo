import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { TodoList } from "../../src/TodoList";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testHiddenListsAreIsolatedPerAccount(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  assertEq(todo.addTask("alice task"), 0);
  ctx("bob.testnet");
  assertEq(todo.addTask("bob task"), 0);
  assertEq(todo.addTask("bob task 2"), 1);

  // Bob completes his own task 0; Alice's task 0 is untouched.
  todo.completeTask(0);
  assertEq(todo.getTask("bob.testnet", 0)?.done, true);
  assertEq(todo.getTask("alice.testnet", 0)?.done, false);
  assertEq(todo.getTask("alice.testnet", 0)?.title, "alice task");
  assertEq(todo.taskCount("alice.testnet"), 1);
  assertEq(todo.taskCount("bob.testnet"), 2);
  assertEq(todo.pendingCount("alice.testnet"), 1);
  assertEq(todo.pendingCount("bob.testnet"), 1);
}

export function testHiddenCannotCompleteMissingOrForeignTask(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  todo.addTask("a0");
  todo.addTask("a1");
  ctx("bob.testnet");
  // Bob has no tasks, so Alice's ids do not exist for him.
  assertThrows(() => todo.completeTask(1), "Task not found");
  assertThrows(() => todo.completeTask(-1), "Task not found");
  assertEq(todo.getTask("alice.testnet", 1)?.done, false);
  assertEq(todo.pendingCount("alice.testnet"), 2);
  assertEq(todo.pendingCount("bob.testnet"), 0);
}

export function testHiddenTitleBoundaries(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  assertThrows(() => todo.addTask(""), "Invalid title");
  assertThrows(() => todo.addTask("t".repeat(101)), "Invalid title");
  assertEq(todo.taskCount("alice.testnet"), 0);
  assertEq(todo.addTask("t".repeat(100)), 0);
  assertEq(todo.addTask("t"), 1);
  assertEq(todo.listTasks("alice.testnet").length, 2);
}

export function testHiddenPendingCountAndListReflectCompletion(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  for (let i = 0; i < 5; i++) todo.addTask("task " + i);
  todo.completeTask(1);
  todo.completeTask(4);
  assertThrows(() => todo.completeTask(4), "Already completed");
  assertEq(todo.pendingCount("alice.testnet"), 3);
  assertEq(todo.taskCount("alice.testnet"), 5);

  const tasks = todo.listTasks("alice.testnet");
  assertEq(tasks.map((t) => (t.done ? "x" : "-")).join(""), "-x--x");
  assertEq(todo.listTasks("nobody.testnet").length, 0);
  // A new task after completions continues the id sequence.
  assertEq(todo.addTask("task 5"), 5);
  assertEq(todo.pendingCount("alice.testnet"), 4);
}

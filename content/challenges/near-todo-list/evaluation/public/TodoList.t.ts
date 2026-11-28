import { near, assert, assertEq, assertThrows } from "near-sdk-js";
import { TodoList } from "../src/TodoList";

function ctx(account: string, timestamp: bigint = 1000n, deposit: bigint = 0n): void {
  near._setContext({
    predecessorAccountId: account,
    signerAccountId: account,
    attachedDeposit: deposit,
    blockTimestamp: timestamp,
  });
}

export function testAddTasksAssignsSequentialIds(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  assertEq(todo.addTask("write contract"), 0);
  assertEq(todo.addTask("write tests"), 1);

  assertEq(todo.taskCount("alice.testnet"), 2);
  assertEq(todo.getTask("alice.testnet", 1)?.title, "write tests");
  assertEq(todo.getTask("alice.testnet", 1)?.done, false);
  assertEq(todo.getTask("alice.testnet", 2), null);
}

export function testCompleteTask(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  todo.addTask("a");
  todo.addTask("b");
  todo.completeTask(0);

  assertEq(todo.getTask("alice.testnet", 0)?.done, true);
  assertEq(todo.getTask("alice.testnet", 1)?.done, false);
  assertEq(todo.pendingCount("alice.testnet"), 1);
  assertThrows(() => todo.completeTask(0), "Already completed");
}

export function testListTasksInOrder(): void {
  const todo = new TodoList();
  ctx("alice.testnet");
  todo.addTask("first");
  todo.addTask("second");
  todo.addTask("third");
  const tasks = todo.listTasks("alice.testnet");
  assertEq(tasks.length, 3);
  assertEq(tasks.map((t) => t.title).join("|"), "first|second|third");
  assertEq(tasks[2]?.id, 2);
}

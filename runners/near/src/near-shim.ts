export const NEAR_SDK_SHIM_TS = `
export interface NearContext {
  predecessorAccountId: string;
  signerAccountId: string;
  currentAccountId: string;
  attachedDeposit: bigint;
  blockTimestamp: bigint;
}

class NearRuntime {
  private ctx: NearContext = {
    predecessorAccountId: "alice.testnet",
    signerAccountId: "alice.testnet",
    currentAccountId: "contract.testnet",
    attachedDeposit: 0n,
    blockTimestamp: 1700000000000000000n,
  };

  _setContext(partial: Partial<NearContext>) {
    this.ctx = { ...this.ctx, ...partial };
  }

  predecessorAccountId(): string {
    return this.ctx.predecessorAccountId;
  }

  signerAccountId(): string {
    return this.ctx.signerAccountId;
  }

  currentAccountId(): string {
    return this.ctx.currentAccountId;
  }

  attachedDeposit(): bigint {
    return this.ctx.attachedDeposit;
  }

  blockTimestamp(): bigint {
    return this.ctx.blockTimestamp;
  }
}

export const near = new NearRuntime();

export class LookupMap<V> {
  private map = new Map<string, V>();
  constructor(public readonly prefix: string) {}
  get(key: string): V | null {
    return this.map.has(key) ? (this.map.get(key) as V) : null;
  }
  set(key: string, value: V): void {
    this.map.set(key, value);
  }
  containsKey(key: string): boolean {
    return this.map.has(key);
  }
  remove(key: string): void {
    this.map.delete(key);
  }
}

export function assert(cond: boolean, msg = "Assertion failed"): void {
  if (!cond) throw new Error(msg);
}

export function assertEq<T>(a: T, b: T, msg?: string): void {
  if (a !== b) {
    throw new Error(msg ?? \`Assertion failed: expected \${String(a)} === \${String(b)}\`);
  }
}

export function assertThrows(fn: () => void, expectedSubstring?: string): void {
  let threw = false;
  try {
    fn();
  } catch (err) {
    threw = true;
    if (expectedSubstring) {
      const msg = err instanceof Error ? err.message : String(err);
      if (!msg.includes(expectedSubstring)) {
        throw new Error(\`Expected error containing "\${expectedSubstring}", got "\${msg}"\`);
      }
    }
  }
  if (!threw) {
    throw new Error(\`Expected function to throw\${expectedSubstring ? \` ("\${expectedSubstring}")\` : ""}\`);
  }
}
`;

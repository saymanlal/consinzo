import { Common, Hardfork, Mainnet } from "@ethereumjs/common";
import { createEVM, type CustomPrecompile, type PrecompileInput } from "@ethereumjs/evm";
import { SimpleStateManager } from "@ethereumjs/statemanager";
import {
  Account,
  Address,
  bytesToHex,
  createAddressFromString,
  createZeroAddress,
  hexToBytes,
} from "@ethereumjs/util";
import { AbiCoder, Interface, SigningKey, keccak256, toUtf8Bytes } from "ethers";
import type { PublicTestResult } from "@consinzo/execution-sdk";
import type { ProjectFile } from "@consinzo/shared";
import { compileSolidityProject, type CompiledContractArtifact } from "./compiler";

// Foundry/HEVM cheatcode precompile: address(uint160(uint256(keccak256("hevm cheat code"))))
const VM_PRECOMPILE_HEX = "0x7109709ecfa91a80626ff3989d68f67f5b1dd12d";
const VM_PRECOMPILE_ADDR = createAddressFromString(VM_PRECOMPILE_HEX);

const DEFAULT_CALLER_ADDR = createAddressFromString("0x1111111111111111111111111111111111111111");
const TEST_CONTRACT_ADDR = createAddressFromString("0x7fa9385be102ac3eac297483dd6233d62b3e1496");

const abiCoder = AbiCoder.defaultAbiCoder();

function selectorOf(sig: string): string {
  return keccak256(toUtf8Bytes(sig)).slice(0, 10).toLowerCase();
}

const SEL_WARP = selectorOf("warp(uint256)");
const SEL_ROLL = selectorOf("roll(uint256)");
const SEL_DEAL = selectorOf("deal(address,uint256)");
const SEL_PRANK = selectorOf("prank(address)");
const SEL_START_PRANK = selectorOf("startPrank(address)");
const SEL_STOP_PRANK = selectorOf("stopPrank()");
const SEL_EXPECT_REVERT_0 = selectorOf("expectRevert()");
const SEL_EXPECT_REVERT_B4 = selectorOf("expectRevert(bytes4)");
const SEL_EXPECT_REVERT_BYTES = selectorOf("expectRevert(bytes)");
const SEL_ADDR = selectorOf("addr(uint256)");

interface CheatcodeState {
  blockTimestamp: bigint;
  blockNumber: bigint;
  nextPrank?: Address;
  persistentPrank?: Address;
  expectRevert?: {
    armed: boolean;
    expectedBytes?: Uint8Array;
    failedReason?: string;
  };
}

function decodeRevertReason(returnValue: Uint8Array): string {
  if (!returnValue || returnValue.length === 0) return "EVM reverted without reason";
  const hex = bytesToHex(returnValue);
  // Error(string) => 0x08c379a0
  if (hex.startsWith("0x08c379a0") && returnValue.length >= 68) {
    try {
      const decoded = abiCoder.decode(["string"], `0x${hex.slice(10)}`);
      return String(decoded[0]);
    } catch {
      return `Revert(${hex.slice(0, 42)}...)`;
    }
  }
  // Panic(uint256) => 0x4e487b71
  if (hex.startsWith("0x4e487b71") && returnValue.length >= 36) {
    try {
      const decoded = abiCoder.decode(["uint256"], `0x${hex.slice(10)}`);
      return `Panic(0x${BigInt(decoded[0]).toString(16)})`;
    } catch {
      return `Panic(${hex})`;
    }
  }
  return `CustomError(${hex.slice(0, 42)})`;
}

function makeBlock(state: CheatcodeState) {
  return {
    header: {
      number: state.blockNumber,
      coinbase: createZeroAddress(),
      timestamp: state.blockTimestamp,
      difficulty: 0n,
      prevRandao: new Uint8Array(32),
      gasLimit: 30_000_000n,
      baseFeePerGas: 0n,
      getBlobGasPrice: () => 0n,
    },
  };
}

async function runSingleTestFunction(
  testArtifact: CompiledContractArtifact,
  testFunctionName: string,
  hasSetUp: boolean,
  timeoutMs: number
): Promise<PublicTestResult> {
  const startedAt = Date.now();
  const state: CheatcodeState = {
    blockTimestamp: 1_700_000_000n,
    blockNumber: 1_000n,
  };
  const liveBlock = makeBlock(state);

  const common = new Common({ chain: Mainnet, hardfork: Hardfork.Paris });
  const stateManager = new SimpleStateManager();

  // Fund default caller and test contract with 10,000 ETH each, and set dummy code on VM precompile
  // so Solidity's EXTCODESIZE check before interface calls succeeds.
  const initialBalance = 10_000n * 10n ** 18n;
  for (const addr of [DEFAULT_CALLER_ADDR, TEST_CONTRACT_ADDR]) {
    const acct = await stateManager.getAccount(addr);
    if (acct) {
      acct.balance = initialBalance;
      await stateManager.putAccount(addr, acct);
    } else {
      await stateManager.putAccount(addr, new Account(0n, initialBalance));
    }
  }
  await stateManager.putAccount(VM_PRECOMPILE_ADDR, new Account(0n, 0n));
  await stateManager.putCode(VM_PRECOMPILE_ADDR, new Uint8Array([0xfe]));

  let evmRef: Awaited<ReturnType<typeof createEVM>>;

  const cheatcodePrecompile: CustomPrecompile = {
    address: VM_PRECOMPILE_ADDR,
    function: async (input: PrecompileInput) => {
      const dataHex = bytesToHex(input.data);
      const sel = dataHex.slice(0, 10).toLowerCase();
      const argsHex = `0x${dataHex.slice(10)}`;

      try {
        if (sel === SEL_WARP) {
          const [ts] = abiCoder.decode(["uint256"], argsHex);
          state.blockTimestamp = BigInt(ts);
          liveBlock.header.timestamp = BigInt(ts);
        } else if (sel === SEL_ROLL) {
          const [bn] = abiCoder.decode(["uint256"], argsHex);
          state.blockNumber = BigInt(bn);
          liveBlock.header.number = BigInt(bn);
        } else if (sel === SEL_DEAL) {
          const [target, amount] = abiCoder.decode(["address", "uint256"], argsHex);
          const targetAddr = createAddressFromString(String(target));
          const existing = (await evmRef.stateManager.getAccount(targetAddr)) ?? new Account();
          existing.balance = BigInt(amount);
          await evmRef.stateManager.putAccount(targetAddr, existing);
        } else if (sel === SEL_PRANK) {
          const [sender] = abiCoder.decode(["address"], argsHex);
          state.nextPrank = createAddressFromString(String(sender));
        } else if (sel === SEL_START_PRANK) {
          const [sender] = abiCoder.decode(["address"], argsHex);
          state.persistentPrank = createAddressFromString(String(sender));
        } else if (sel === SEL_STOP_PRANK) {
          state.persistentPrank = undefined;
          state.nextPrank = undefined;
        } else if (sel === SEL_EXPECT_REVERT_0) {
          state.expectRevert = { armed: true };
        } else if (sel === SEL_EXPECT_REVERT_B4) {
          const [b4] = abiCoder.decode(["bytes4"], argsHex);
          state.expectRevert = { armed: true, expectedBytes: hexToBytes(b4 as `0x${string}`) };
        } else if (sel === SEL_EXPECT_REVERT_BYTES) {
          const [raw] = abiCoder.decode(["bytes"], argsHex);
          state.expectRevert = { armed: true, expectedBytes: hexToBytes(raw as `0x${string}`) };
        } else if (sel === SEL_ADDR) {
          const [pk] = abiCoder.decode(["uint256"], argsHex);
          const pkHex = `0x${BigInt(pk).toString(16).padStart(64, "0")}`;
          const derived = new SigningKey(pkHex);
          const { computeAddress } = await import("ethers");
          const addr = computeAddress(derived.publicKey);
          const encoded = abiCoder.encode(["address"], [addr]);
          return {
            executionGasUsed: 100n,
            returnValue: hexToBytes(encoded as `0x${string}`),
          };
        }
      } catch (err) {
        return {
          executionGasUsed: 100n,
          returnValue: new Uint8Array(),
          exceptionError: { error: "cheatcode_error", errorType: "CheatcodeError", message: (err as Error).message } as never,
        };
      }

      return {
        executionGasUsed: 100n,
        returnValue: new Uint8Array(),
      };
    },
  };

  evmRef = await createEVM({
    common,
    stateManager,
    allowUnlimitedContractSize: true,
    customPrecompiles: [cheatcodePrecompile],
  });

  // Track call frames so prank & expectRevert apply strictly to the depth-1 frame from test contract
  let expectedRevertDepth: number | null = null;
  const frameDepthStack: number[] = [];
  let targetTestContractHex = TEST_CONTRACT_ADDR.toString().toLowerCase();

  evmRef.events.on("beforeMessage", async (msg, resolve) => {
    frameDepthStack.push(msg.depth);
    const toHex = msg.to ? msg.to.toString().toLowerCase() : "";
    const callerHex = msg.caller.toString().toLowerCase();
    const isVmCall = toHex === VM_PRECOMPILE_HEX;

    if (!isVmCall && callerHex === targetTestContractHex && msg.depth === 1) {
      let prankTarget: Address | undefined;
      if (state.nextPrank) {
        prankTarget = state.nextPrank;
        state.nextPrank = undefined;
      } else if (state.persistentPrank) {
        prankTarget = state.persistentPrank;
      }

      if (prankTarget) {
        if (!msg.to) {
          // CREATE/CREATE2 expects the caller's nonce to have already been incremented (>= 1)
          const acct = (await evmRef.stateManager.getAccount(prankTarget)) ?? new Account();
          acct.nonce += 1n;
          await evmRef.stateManager.putAccount(prankTarget, acct);
        }
        msg.caller = prankTarget;
      }

      if (state.expectRevert?.armed && expectedRevertDepth === null) {
        expectedRevertDepth = msg.depth;
      }
    }
    resolve?.();
  });

  evmRef.events.on("afterMessage", (result, resolve) => {
    const poppedDepth = frameDepthStack.pop();

    if (
      expectedRevertDepth !== null &&
      poppedDepth === expectedRevertDepth &&
      state.expectRevert?.armed
    ) {
      expectedRevertDepth = null;
      const expected = state.expectRevert;
      state.expectRevert = undefined;

      if (!result.execResult.exceptionError) {
        state.expectRevert = {
          armed: false,
          failedReason: "Expected call to revert, but it succeeded",
        };
      } else {
        if (expected.expectedBytes && expected.expectedBytes.length > 0) {
          const actual = result.execResult.returnValue;
          const expectedHex = bytesToHex(expected.expectedBytes).toLowerCase();
          const actualHex = bytesToHex(actual).toLowerCase();
          const decodedReason = decodeRevertReason(actual);
          const expectedText = Buffer.from(expected.expectedBytes).toString("utf8");

          const matchesSelector = actualHex.startsWith(expectedHex);
          const matchesMessage =
            decodedReason === expectedText || actualHex.includes(expectedHex.slice(2));
          if (!matchesSelector && !matchesMessage) {
            state.expectRevert = {
              armed: false,
              failedReason: `Reverted with unexpected reason: "${decodedReason}"`,
            };
          }
        }
        if (!state.expectRevert?.failedReason) {
          result.execResult.exceptionError = undefined;
          // Provide a 128-byte zeroed ABI-safe buffer so Solidity's post-CALL RETURNDATASIZE
          // and strict bool (0/1) / dynamic bytes offset-length checks all pass cleanly.
          result.execResult.returnValue = new Uint8Array(128);
        }
      }
    }
    resolve?.();
  });

  const iface = new Interface(testArtifact.abi as never[]);

  const runPromise = (async (): Promise<PublicTestResult> => {
    // 1. Deploy test contract at TEST_CONTRACT_ADDR
    const initCode = hexToBytes(`0x${testArtifact.bytecode}`);
    const deployRes = await evmRef.runCall({
      caller: DEFAULT_CALLER_ADDR,
      to: undefined,
      data: initCode,
      gasLimit: 10_000_000n,
      block: liveBlock,
    });

    // If created address differs from TEST_CONTRACT_ADDR, copy deployed code & storage to TEST_CONTRACT_ADDR
    // Actually in runCall with to: undefined, createdAddress is computed from caller nonce; let's call the created address directly OR overwrite TEST_CONTRACT_ADDR!
    // Wait: msg.sender inside test contract will be TEST_CONTRACT_ADDR if we call createdAddress; let's bind testAddr dynamically!
    if (deployRes.execResult.exceptionError || !deployRes.createdAddress) {
      return {
        name: testFunctionName,
        contract: testArtifact.contractName,
        passed: false,
        durationMs: Date.now() - startedAt,
        reason: `Test contract deployment failed: ${decodeRevertReason(deployRes.execResult.returnValue)}`,
      };
    }

    const deployedAddr = deployRes.createdAddress;
    // Fund the deployed test contract with 10,000 ETH for payable test calls
    const deployedAcct = (await evmRef.stateManager.getAccount(deployedAddr)) ?? new Account();
    deployedAcct.balance = initialBalance;
    await evmRef.stateManager.putAccount(deployedAddr, deployedAcct);

    const deployedAddrHex = deployedAddr.toString().toLowerCase();
    // Patch listener via closure variable
    targetTestContractHex = deployedAddrHex;

    // 2. Call setUp() if present
    if (hasSetUp) {
      const setUpData = hexToBytes(iface.encodeFunctionData("setUp", []) as `0x${string}`);
      const setUpRes = await evmRef.runCall({
        caller: DEFAULT_CALLER_ADDR,
        to: deployedAddr,
        data: setUpData,
        gasLimit: 10_000_000n,
        block: liveBlock,
      });
      if (setUpRes.execResult.exceptionError) {
        return {
          name: testFunctionName,
          contract: testArtifact.contractName,
          passed: false,
          gasUsed: Number(setUpRes.execResult.executionGasUsed),
          durationMs: Date.now() - startedAt,
          reason: `setUp() reverted: ${decodeRevertReason(setUpRes.execResult.returnValue)}`,
        };
      }
    }

    // 3. Call the test function
    const callData = hexToBytes(iface.encodeFunctionData(testFunctionName, []) as `0x${string}`);
    const testRes = await evmRef.runCall({
      caller: DEFAULT_CALLER_ADDR,
      to: deployedAddr,
      data: callData,
      gasLimit: 10_000_000n,
      block: liveBlock,
    });

    const gasUsed = Number(testRes.execResult.executionGasUsed);

    if (state.expectRevert?.failedReason) {
      return {
        name: testFunctionName,
        contract: testArtifact.contractName,
        passed: false,
        gasUsed,
        durationMs: Date.now() - startedAt,
        reason: state.expectRevert.failedReason,
      };
    }

    if (state.expectRevert?.armed) {
      return {
        name: testFunctionName,
        contract: testArtifact.contractName,
        passed: false,
        gasUsed,
        durationMs: Date.now() - startedAt,
        reason: "vm.expectRevert() was armed but no external call followed",
      };
    }

    if (testRes.execResult.exceptionError) {
      return {
        name: testFunctionName,
        contract: testArtifact.contractName,
        passed: false,
        gasUsed,
        durationMs: Date.now() - startedAt,
        reason: decodeRevertReason(testRes.execResult.returnValue),
      };
    }

    return {
      name: testFunctionName,
      contract: testArtifact.contractName,
      passed: true,
      gasUsed,
      durationMs: Date.now() - startedAt,
    };
  })();

  const timeoutPromise = new Promise<PublicTestResult>((resolve) => {
    setTimeout(() => {
      resolve({
        name: testFunctionName,
        contract: testArtifact.contractName,
        passed: false,
        durationMs: timeoutMs,
        reason: `Test timed out after ${timeoutMs}ms`,
      });
    }, timeoutMs);
  });

  return Promise.race([runPromise, timeoutPromise]);
}

export async function runSolidityTestsInEvm(
  files: ProjectFile[],
  options: { timeoutMs?: number; targetTestFilePrefix?: string } = {}
) {
  const startedAt = Date.now();
  const timeoutMs = options.timeoutMs ?? 15_000;
  const compilation = compileSolidityProject(files);

  if (!compilation.compiled) {
    return {
      compiled: false,
      compilerVersion: compilation.compilerVersion,
      diagnostics: compilation.diagnostics,
      results: [] as PublicTestResult[],
      totalDurationMs: Date.now() - startedAt,
    };
  }

  // Find test contracts: either in test/ or contract name ends with Test and has test*() functions
  const testArtifacts = compilation.contracts.filter((c) => {
    if (options.targetTestFilePrefix && !c.sourcePath.startsWith(options.targetTestFilePrefix)) {
      return false;
    }
    const isTestPath = c.sourcePath.startsWith("test/") || c.sourcePath.startsWith("evaluation/") || c.contractName.endsWith("Test");
    if (!isTestPath) return false;
    const abiFns = (c.abi as Array<{ type?: string; name?: string }>).filter(
      (item) => item.type === "function" && item.name?.startsWith("test")
    );
    return abiFns.length > 0;
  });

  const results: PublicTestResult[] = [];

  for (const artifact of testArtifacts) {
    const abiItems = artifact.abi as Array<{ type?: string; name?: string; inputs?: unknown[] }>;
    const hasSetUp = abiItems.some((item) => item.type === "function" && item.name === "setUp");
    const testFns = abiItems
      .filter((item) => item.type === "function" && item.name?.startsWith("test") && (item.inputs?.length ?? 0) === 0)
      .map((item) => item.name!);

    for (const fnName of testFns) {
      const res = await runSingleTestFunction(artifact, fnName, hasSetUp, timeoutMs);
      results.push(res);
    }
  }

  return {
    compiled: true,
    compilerVersion: compilation.compilerVersion,
    diagnostics: compilation.diagnostics,
    results,
    totalDurationMs: Date.now() - startedAt,
  };
}

import { describe, expect, it } from "vitest";
import { EvmRunner } from "./index";

describe("@consinzo/runner-evm", () => {
  const runner = new EvmRunner();

  it("compiles valid Solidity, executes Foundry-style tests with cheatcodes, and reports gas", async () => {
    const report = await runner.runTests([
      {
        path: "src/Vault.sol",
        content: `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Vault {
    address public owner;
    mapping(address => uint256) public balances;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "INSUFFICIENT_BALANCE");
        balances[msg.sender] -= amount;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");
    }
}`,
      },
      {
        path: "test/Vault.t.sol",
        content: `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract VaultTest is Test {
    Vault public vault;
    address public alice = address(0xA11CE);

    function setUp() public {
        vault = new Vault();
        vm.deal(alice, 5 ether);
    }

    function testDepositAndWithdraw() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();
        assertEq(vault.balances(alice), 2 ether);

        vm.prank(alice);
        vault.withdraw(1 ether);
        assertEq(vault.balances(alice), 1 ether);
    }

    function testWithdrawOverBalanceReverts() public {
        vm.prank(alice);
        vm.expectRevert("INSUFFICIENT_BALANCE");
        vault.withdraw(1 ether);
    }
}`,
      },
    ]);

    expect(report.compiled).toBe(true);
    expect(report.status).toBe("passed");
    expect(report.publicTests).toHaveLength(2);
    expect(report.publicTests.every((t) => t.passed)).toBe(true);
    expect(report.averageGasUsed).toBeGreaterThan(0);
  });

  it("reports real compiler diagnostics on syntax/type errors", async () => {
    const report = await runner.runTests([
      {
        path: "src/Broken.sol",
        content: `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract Broken {
    function bad() public pure returns (uint256) {
        return "not_a_uint";
    }
}`,
      },
    ]);

    expect(report.compiled).toBe(false);
    expect(report.status).toBe("compilation_error");
    expect(report.diagnostics.length).toBeGreaterThan(0);
    expect(report.diagnostics[0]?.severity).toBe("error");
    expect(report.diagnostics[0]?.line).toBeGreaterThan(0);
  });
});

# Reference Solution Explanation

## Root cause

`run` executed `plugin.delegatecall(data)` with both arguments taken from the caller and no
restriction on the caller. Under `delegatecall` the callee's code reads and writes the
caller's storage and spends the caller's ETH. Supplying your own contract as `plugin` is
therefore equivalent to replacing the wallet's code for one call: a single `sstore(0, x)`
makes the attacker the owner, and `address(this).balance` is the wallet's balance.

The approved-plugin list existed but was never read on the execution path.

## Fix

```solidity
function run(address plugin, bytes calldata data) external onlyOwner returns (bytes memory) {
    if (!approvedPlugin[plugin]) revert PluginNotApproved();
    ...
}
```

Both conditions are needed:

- **Approved target** stops arbitrary code from running in the wallet's context.
- **Owner-only caller** stops strangers from driving approved code with their own arguments.
  The batch payer is safe code, yet `pay([attacker], [balance])` empties the wallet.

Because `setPlugin` only approves addresses with code, and `run` requires approval, the
"delegatecall to an address without code succeeds and does nothing" trap is also closed.

## Pitfalls

- Checking only `plugin.code.length > 0` or only the selector does not constrain the code.
- Caching approvals elsewhere (for example in the plugin) defeats revocation.
- Plugins share the wallet's storage layout. Approving a plugin that declares its own state
  variables can corrupt `owner`; plugins should be stateless or use namespaced slots.

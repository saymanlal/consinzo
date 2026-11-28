# Reference Solution Explanation

## Address derivation

```
create2Salt = keccak256(abi.encodePacked(sender, salt))
proxy       = keccak256(0xff ++ deployer ++ create2Salt ++ keccak256(PROXY_INITCODE))[12:]
deployed    = keccak256(0xd6 ++ 0x94 ++ proxy ++ 0x01)[12:]
```

The last line is the ordinary `CREATE` formula, `keccak256(rlp([proxy, 1]))`, written out:
the list holds a 20-byte string (`0x94` + bytes) and the integer 1 (`0x01`), 22 payload
bytes in total, hence the prefix `0xc0 + 22 = 0xd6`. The nonce is 1 because contracts start
at nonce 1 and the proxy has created nothing before.

None of the inputs involves the init code of the contract being deployed.

## deploy

1. `create2` the proxy. A zero result means an account already exists there, which in this
   contract can only mean the caller has used the salt before.
2. `proxy.call{value: msg.value}(initCode)`. The proxy runs `CREATE(callvalue, 0,
   calldatasize)` with the calldata as init code, so both the code and the ether go to the
   new contract.
3. Check `deployed.code.length != 0`. The proxy never reverts; if the constructor reverts,
   `CREATE` pushes zero and the proxy simply stops. Without the code check the function
   would report success for a contract that does not exist.

Because failures revert the whole transaction, the proxy created in step 1 disappears
again and the salt remains usable.

## Pitfalls

- Using the raw `salt` for CREATE2. Anyone could then deploy arbitrary code at the address
  a team has announced, simply by calling `deploy` first with the same salt.
- Trusting the success flag of the call to the proxy.
- Computing the final address with nonce 0.
- Forgetting to forward `msg.value`, which leaves ether stuck in the deployer.

## Things to know when using CREATE3

Inside the constructor, `msg.sender` is the proxy, not the user and not the deployer.
Contracts that assign ownership to `msg.sender` in the constructor need an explicit owner
argument instead.

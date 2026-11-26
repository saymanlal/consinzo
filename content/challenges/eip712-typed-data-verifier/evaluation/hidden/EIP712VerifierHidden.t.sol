// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/EIP712Verifier.sol";

contract EIP712VerifierHiddenTest is Test {
    function testHiddenOrderHashMatchesEIP712Spec() public {
        EIP712Verifier v = new EIP712Verifier("Consinzo", "1");
        bytes32 expected = keccak256(abi.encode(v.ORDER_TYPEHASH(), address(0x111), uint256(42), uint256(7)));
        assertEq(v.hashOrder(address(0x111), 42, 7), expected);
    }
}
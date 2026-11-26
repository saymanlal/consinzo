// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/EIP712Verifier.sol";

contract EIP712VerifierTest is Test {
    function testDomainAndTypedDigestDeterministic() public {
        EIP712Verifier v1 = new EIP712Verifier("Consinzo", "1");
        EIP712Verifier v2 = new EIP712Verifier("Consinzo", "1");
        assertTrue(v1.domainSeparator() != v2.domainSeparator());
        bytes32 sh = v1.hashOrder(address(0xA11CE), 100, 0);
        bytes32 expected = keccak256(abi.encodePacked("\x19\x01", v1.domainSeparator(), sh));
        assertEq(v1.computeTypedDigest(sh), expected);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PermitVault {
    mapping(address => uint256) public nonces;
    mapping(address => mapping(address => uint256)) public allowance;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 digest = keccak256(abi.encode(block.chainid, address(this), owner, spender, value, nonces[owner], deadline));
        address recovered = ecrecover(digest, v, r, s);
        require(recovered == owner, "INVALID_SIG");
        allowance[owner][spender] = value;
    }
}
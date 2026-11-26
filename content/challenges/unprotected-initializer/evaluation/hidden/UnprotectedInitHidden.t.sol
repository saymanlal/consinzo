// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/Exploit.sol";

contract TargetVaultH {
    address public owner;
    constructor() payable {}
    function initialize(address _owner) external { owner = _owner; }
    function sweep(address payable to) external {
        require(msg.sender == owner, "NOT_OWNER");
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok);
    }
}

contract UnprotectedInitHiddenTest is Test {
    function testHiddenExploitWorksWithNonZeroInitialOwner() public {
        TargetVaultH v = new TargetVaultH{value: 7 ether}();
        v.initialize(address(0x1111));
        Exploit ex = new Exploit();
        ex.pwn(address(v));
        assertEq(address(v).balance, 0);
        assertEq(address(ex).balance, 7 ether);
    }
}
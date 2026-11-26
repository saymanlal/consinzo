export const FORGE_STD_VM_SOL = `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface Vm {
    function warp(uint256 newTimestamp) external;
    function roll(uint256 newHeight) external;
    function deal(address account, uint256 newBalance) external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function addr(uint256 privateKey) external pure returns (address);
}
`;

export const FORGE_STD_TEST_SOL = `// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./Vm.sol";

abstract contract Test {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool condition) internal pure {
        require(condition, "Assertion failed: expected true");
    }

    function assertTrue(bool condition, string memory err) internal pure {
        require(condition, err);
    }

    function assertFalse(bool condition) internal pure {
        require(!condition, "Assertion failed: expected false");
    }

    function assertFalse(bool condition, string memory err) internal pure {
        require(!condition, err);
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "Assertion failed: uint256 a != b");
    }

    function assertEq(uint256 a, uint256 b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(int256 a, int256 b) internal pure {
        require(a == b, "Assertion failed: int256 a != b");
    }

    function assertEq(address a, address b) internal pure {
        require(a == b, "Assertion failed: address a != b");
    }

    function assertEq(address a, address b, string memory err) internal pure {
        require(a == b, err);
    }

    function assertEq(bool a, bool b) internal pure {
        require(a == b, "Assertion failed: bool a != b");
    }

    function assertEq(bytes32 a, bytes32 b) internal pure {
        require(a == b, "Assertion failed: bytes32 a != b");
    }

    function assertEq(string memory a, string memory b) internal pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), "Assertion failed: string a != b");
    }

    function assertNotEq(uint256 a, uint256 b) internal pure {
        require(a != b, "Assertion failed: uint256 a == b");
    }

    function assertNotEq(address a, address b) internal pure {
        require(a != b, "Assertion failed: address a == b");
    }

    function assertGt(uint256 a, uint256 b) internal pure {
        require(a > b, "Assertion failed: expected a > b");
    }

    function assertGe(uint256 a, uint256 b) internal pure {
        require(a >= b, "Assertion failed: expected a >= b");
    }

    function assertLt(uint256 a, uint256 b) internal pure {
        require(a < b, "Assertion failed: expected a < b");
    }

    function assertLe(uint256 a, uint256 b) internal pure {
        require(a <= b, "Assertion failed: expected a <= b");
    }
}
`;

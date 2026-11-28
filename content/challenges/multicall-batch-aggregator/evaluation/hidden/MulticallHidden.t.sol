// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Multicall.sol";

contract HiddenTarget {
    error Boom(uint256 code);

    uint256 public counter;
    mapping(address => uint256) public seen;

    function increment(uint256 by) external returns (uint256) {
        counter += by;
        seen[msg.sender] += 1;
        return counter;
    }

    function fail(uint256 code) external pure {
        revert Boom(code);
    }

    function failWithString() external pure {
        revert("plain reason");
    }

    function failSilently() external pure {
        assembly {
            revert(0, 0)
        }
    }

    function echo(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }

    function nothing() external pure {}
}

contract MulticallHiddenTest is Test {
    Multicall public multicall;
    HiddenTarget public a;
    HiddenTarget public b;

    function setUp() public {
        multicall = new Multicall();
        a = new HiddenTarget();
        b = new HiddenTarget();
    }

    function testHiddenEmptyBatch() public {
        Multicall.Call[] memory calls = new Multicall.Call[](0);
        (uint256 blockNumber, Multicall.Result[] memory results) = multicall.aggregate(calls);
        assertEq(results.length, 0);
        assertEq(blockNumber, 1000);
        vm.roll(4321);
        (blockNumber,) = multicall.aggregate(calls);
        assertEq(blockNumber, 4321);
    }

    function testHiddenCallFailedCarriesIndexAndData() public {
        Multicall.Call[] memory calls = new Multicall.Call[](3);
        calls[0] = Multicall.Call(address(a), true, abi.encodeCall(HiddenTarget.fail, (1)));
        calls[1] = Multicall.Call(address(b), false, abi.encodeCall(HiddenTarget.increment, (3)));
        calls[2] = Multicall.Call(address(b), false, abi.encodeCall(HiddenTarget.fail, (99)));

        bytes memory inner = abi.encodeWithSelector(HiddenTarget.Boom.selector, uint256(99));
        vm.expectRevert(abi.encodeWithSelector(Multicall.CallFailed.selector, uint256(2), inner));
        multicall.aggregate(calls);
        assertEq(b.counter(), 0);
    }

    function testHiddenTargetWithoutCodeRevertsEvenWhenFailureAllowed() public {
        Multicall.Call[] memory calls = new Multicall.Call[](2);
        calls[0] = Multicall.Call(address(a), false, abi.encodeCall(HiddenTarget.increment, (1)));
        calls[1] = Multicall.Call(address(0xC0FFEE), true, abi.encodeCall(HiddenTarget.increment, (1)));

        vm.expectRevert(abi.encodeWithSelector(Multicall.TargetNotContract.selector, uint256(1)));
        multicall.aggregate(calls);
        assertEq(a.counter(), 0);
    }

    function testHiddenRawRevertDataIsPreserved() public {
        Multicall.Call[] memory calls = new Multicall.Call[](4);
        calls[0] = Multicall.Call(address(a), true, abi.encodeCall(HiddenTarget.failWithString, ()));
        calls[1] = Multicall.Call(address(a), true, abi.encodeCall(HiddenTarget.failSilently, ()));
        calls[2] = Multicall.Call(address(a), true, hex"deadbeef");
        calls[3] = Multicall.Call(address(a), true, abi.encodeCall(HiddenTarget.nothing, ()));

        (, Multicall.Result[] memory results) = multicall.aggregate(calls);

        assertFalse(results[0].success);
        assertEq(keccak256(results[0].returnData), keccak256(abi.encodeWithSignature("Error(string)", "plain reason")));
        assertFalse(results[1].success);
        assertEq(results[1].returnData.length, 0);
        assertFalse(results[2].success);
        assertTrue(results[3].success);
        assertEq(results[3].returnData.length, 0);
    }

    function testHiddenDynamicReturnDataAndMultipleTargets() public {
        bytes memory payload = hex"000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021";
        Multicall.Call[] memory calls = new Multicall.Call[](4);
        calls[0] = Multicall.Call(address(a), false, abi.encodeCall(HiddenTarget.echo, (payload)));
        calls[1] = Multicall.Call(address(b), false, abi.encodeCall(HiddenTarget.increment, (10)));
        calls[2] = Multicall.Call(address(a), false, abi.encodeCall(HiddenTarget.increment, (4)));
        calls[3] = Multicall.Call(address(b), false, abi.encodeCall(HiddenTarget.increment, (1)));

        (, Multicall.Result[] memory results) = multicall.aggregate(calls);

        assertEq(keccak256(abi.decode(results[0].returnData, (bytes))), keccak256(payload));
        assertEq(abi.decode(results[1].returnData, (uint256)), 10);
        assertEq(abi.decode(results[2].returnData, (uint256)), 4);
        assertEq(abi.decode(results[3].returnData, (uint256)), 11);
        assertEq(a.seen(address(multicall)), 1);
        assertEq(b.seen(address(multicall)), 2);
        assertEq(a.seen(address(this)), 0);
    }

    function testHiddenAllFailuresAllowed() public {
        Multicall.Call[] memory calls = new Multicall.Call[](3);
        for (uint256 i = 0; i < 3; i++) {
            calls[i] = Multicall.Call(address(a), true, abi.encodeCall(HiddenTarget.fail, (i)));
        }
        (, Multicall.Result[] memory results) = multicall.aggregate(calls);
        for (uint256 i = 0; i < 3; i++) {
            assertFalse(results[i].success);
            assertEq(keccak256(results[i].returnData), keccak256(abi.encodeWithSelector(HiddenTarget.Boom.selector, i)));
        }
    }
}

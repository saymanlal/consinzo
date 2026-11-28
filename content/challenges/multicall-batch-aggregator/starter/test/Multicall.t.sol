// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Multicall.sol";

contract MulticallTarget {
    error Boom(uint256 code);

    uint256 public counter;
    address public lastCaller;

    function increment(uint256 by) external returns (uint256) {
        counter += by;
        lastCaller = msg.sender;
        return counter;
    }

    function fail(uint256 code) external pure {
        revert Boom(code);
    }

    function echo(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }
}

contract MulticallTest is Test {
    Multicall public multicall;
    MulticallTarget public target;

    function setUp() public {
        multicall = new Multicall();
        target = new MulticallTarget();
    }

    function _call(bool allowFailure, bytes memory data) internal view returns (Multicall.Call memory) {
        return Multicall.Call({target: address(target), allowFailure: allowFailure, callData: data});
    }

    function testAggregateRunsCallsInOrder() public {
        Multicall.Call[] memory calls = new Multicall.Call[](3);
        calls[0] = _call(false, abi.encodeCall(MulticallTarget.increment, (2)));
        calls[1] = _call(false, abi.encodeCall(MulticallTarget.increment, (5)));
        calls[2] = _call(false, abi.encodeWithSignature("counter()"));

        (uint256 blockNumber, Multicall.Result[] memory results) = multicall.aggregate(calls);

        assertEq(blockNumber, block.number);
        assertEq(results.length, 3);
        assertTrue(results[0].success);
        assertEq(abi.decode(results[0].returnData, (uint256)), 2);
        assertEq(abi.decode(results[1].returnData, (uint256)), 7);
        assertEq(abi.decode(results[2].returnData, (uint256)), 7);
        assertEq(target.counter(), 7);
        assertEq(target.lastCaller(), address(multicall));
    }

    function testAllowedFailureIsReported() public {
        Multicall.Call[] memory calls = new Multicall.Call[](3);
        calls[0] = _call(false, abi.encodeCall(MulticallTarget.increment, (1)));
        calls[1] = _call(true, abi.encodeCall(MulticallTarget.fail, (42)));
        calls[2] = _call(false, abi.encodeCall(MulticallTarget.increment, (1)));

        (, Multicall.Result[] memory results) = multicall.aggregate(calls);

        assertTrue(results[0].success);
        assertFalse(results[1].success);
        assertEq(
            keccak256(results[1].returnData),
            keccak256(abi.encodeWithSelector(MulticallTarget.Boom.selector, uint256(42)))
        );
        assertTrue(results[2].success);
        assertEq(target.counter(), 2);
    }

    function testMandatoryFailureRevertsBatch() public {
        Multicall.Call[] memory calls = new Multicall.Call[](2);
        calls[0] = _call(false, abi.encodeCall(MulticallTarget.increment, (1)));
        calls[1] = _call(false, abi.encodeCall(MulticallTarget.fail, (7)));

        vm.expectRevert(Multicall.CallFailed.selector);
        multicall.aggregate(calls);
        assertEq(target.counter(), 0);
    }

    function testTargetWithoutCodeReverts() public {
        Multicall.Call[] memory calls = new Multicall.Call[](1);
        calls[0] = Multicall.Call({target: address(0xBEEF), allowFailure: false, callData: hex"12345678"});

        vm.expectRevert(abi.encodeWithSelector(Multicall.TargetNotContract.selector, uint256(0)));
        multicall.aggregate(calls);
    }
}

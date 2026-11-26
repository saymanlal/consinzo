// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract TimelockController {
    uint256 public constant MIN_DELAY = 2 days;
    uint256 public constant GRACE_PERIOD = 14 days;

    address public admin;
    mapping(bytes32 => bool) public queued;

    modifier onlyAdmin() {
        require(msg.sender == admin, "ONLY_ADMIN");
        _;
    }

    constructor(address _admin) {
        require(_admin != address(0), "ZERO_ADMIN");
        admin = _admin;
    }

    function getTxHash(address target, uint256 value, bytes calldata data, uint256 eta) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, data, eta));
    }

    function queue(address target, uint256 value, bytes calldata data, uint256 eta) external onlyAdmin returns (bytes32 txHash) {
        require(target != address(0), "ZERO_TARGET");
        require(eta >= block.timestamp + MIN_DELAY, "ETA_TOO_SOON");
        txHash = getTxHash(target, value, data, eta);
        require(!queued[txHash], "ALREADY_QUEUED");
        queued[txHash] = true;
    }

    function cancel(bytes32 txHash) external onlyAdmin {
        require(queued[txHash], "NOT_QUEUED");
        queued[txHash] = false;
    }

    function execute(address target, uint256 value, bytes calldata data, uint256 eta) external onlyAdmin returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, data, eta);
        require(queued[txHash], "NOT_QUEUED");
        require(block.timestamp >= eta, "TIMELOCK_NOT_READY");
        require(block.timestamp <= eta + GRACE_PERIOD, "TIMELOCK_EXPIRED");
        queued[txHash] = false;
        (bool ok, bytes memory res) = target.call{value: value}(data);
        require(ok, "EXECUTION_FAILED");
        return res;
    }
}

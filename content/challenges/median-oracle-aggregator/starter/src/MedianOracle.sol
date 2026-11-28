// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MedianOracle {
    uint256 public constant MAX_REPORTERS = 16;
    uint256 public constant BPS = 10_000;

    struct Report {
        uint128 price;
        uint64 updatedAt; // 0 means "no report"
    }

    address public immutable owner;
    uint256 public immutable minReports;
    uint256 public immutable maxAge;
    uint256 public immutable maxDeviationBps;

    mapping(address => bool) public isReporter;
    mapping(address => Report) public reports;
    address[] internal _reporters;

    event Reported(address indexed reporter, uint256 price);
    event ReporterAdded(address indexed reporter);
    event ReporterRemoved(address indexed reporter);

    error NotOwner();
    error NotReporter();
    error ZeroAddress();
    error DuplicateReporter();
    error TooManyReporters();
    error InvalidConfig();
    error InvalidPrice();
    error InsufficientReports();
    error DeviationTooHigh();

    constructor(address[] memory reporters_, uint256 minReports_, uint256 maxAge_, uint256 maxDeviationBps_) {
        // TODO: validate the reporter list (cap, zero address, duplicates) and register it
        // TODO: validate minReports_, maxAge_ and maxDeviationBps_ (InvalidConfig)
        owner = msg.sender;
        minReports = minReports_;
        maxAge = maxAge_;
        maxDeviationBps = maxDeviationBps_;
    }

    function reporterCount() external view returns (uint256) {
        return _reporters.length;
    }

    function addReporter(address reporter) external {
        // TODO: owner only; ZeroAddress, DuplicateReporter, TooManyReporters
        revert("NOT_IMPLEMENTED");
    }

    function removeReporter(address reporter) external {
        // TODO: owner only; NotReporter; keep at least minReports reporters; delete the stored report
        revert("NOT_IMPLEMENTED");
    }

    function report(uint256 price) external {
        // TODO: reporters only; reject 0 and values above type(uint128).max; store (price, block.timestamp)
        revert("NOT_IMPLEMENTED");
    }

    function freshCount() external view returns (uint256) {
        // TODO: number of reports with block.timestamp - updatedAt <= maxAge
        revert("NOT_IMPLEMENTED");
    }

    function latestPrice() external view returns (uint256) {
        // TODO: InsufficientReports if fewer than minReports fresh reports
        // TODO: median of the fresh prices (even count: floor of the average of the two middle values)
        // TODO: DeviationTooHigh if fewer than minReports fresh reports lie within maxDeviationBps of the median
        revert("NOT_IMPLEMENTED");
    }

    function tryLatestPrice() external view returns (bool ok, uint256 price) {
        // TODO: same evaluation as latestPrice(), but return (false, 0) instead of reverting
        revert("NOT_IMPLEMENTED");
    }
}

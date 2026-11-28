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

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address[] memory reporters_, uint256 minReports_, uint256 maxAge_, uint256 maxDeviationBps_) {
        if (reporters_.length > MAX_REPORTERS) revert TooManyReporters();
        for (uint256 i = 0; i < reporters_.length; i++) {
            _addReporter(reporters_[i]);
        }
        if (
            minReports_ == 0 || minReports_ > reporters_.length || maxAge_ == 0 || maxDeviationBps_ == 0
                || maxDeviationBps_ > BPS
        ) revert InvalidConfig();

        owner = msg.sender;
        minReports = minReports_;
        maxAge = maxAge_;
        maxDeviationBps = maxDeviationBps_;
    }

    // ---------------------------------------------------------------- reporters

    function reporterCount() external view returns (uint256) {
        return _reporters.length;
    }

    function addReporter(address reporter) external onlyOwner {
        if (reporter == address(0)) revert ZeroAddress();
        if (isReporter[reporter]) revert DuplicateReporter();
        if (_reporters.length >= MAX_REPORTERS) revert TooManyReporters();
        _addReporter(reporter);
    }

    function removeReporter(address reporter) external onlyOwner {
        if (!isReporter[reporter]) revert NotReporter();
        uint256 n = _reporters.length;
        // The oracle must stay able to reach its own quorum.
        if (n - 1 < minReports) revert InvalidConfig();

        for (uint256 i = 0; i < n; i++) {
            if (_reporters[i] == reporter) {
                _reporters[i] = _reporters[n - 1];
                _reporters.pop();
                break;
            }
        }
        isReporter[reporter] = false;
        // Wipe the report: otherwise it would come back to life if the address were re-added.
        delete reports[reporter];
        emit ReporterRemoved(reporter);
    }

    function _addReporter(address reporter) internal {
        if (reporter == address(0)) revert ZeroAddress();
        if (isReporter[reporter]) revert DuplicateReporter();
        isReporter[reporter] = true;
        _reporters.push(reporter);
        emit ReporterAdded(reporter);
    }

    // ---------------------------------------------------------------- reporting

    function report(uint256 price) external {
        if (!isReporter[msg.sender]) revert NotReporter();
        // The uint128 bound keeps `price * BPS` and the median average far from overflow.
        if (price == 0 || price > type(uint128).max) revert InvalidPrice();
        reports[msg.sender] = Report({price: uint128(price), updatedAt: uint64(block.timestamp)});
        emit Reported(msg.sender, price);
    }

    // ---------------------------------------------------------------- reading

    function freshCount() external view returns (uint256) {
        return _freshPrices().length;
    }

    function latestPrice() external view returns (uint256) {
        (uint8 status, uint256 median) = _evaluate();
        if (status == 1) revert InsufficientReports();
        if (status == 2) revert DeviationTooHigh();
        return median;
    }

    function tryLatestPrice() external view returns (bool ok, uint256 price) {
        (uint8 status, uint256 median) = _evaluate();
        if (status != 0) return (false, 0);
        return (true, median);
    }

    /// @dev status: 0 = ok, 1 = not enough fresh reports, 2 = not enough reports agree with the median.
    function _evaluate() internal view returns (uint8 status, uint256 median) {
        uint256[] memory prices = _freshPrices();
        uint256 n = prices.length;
        if (n < minReports) return (1, 0);

        _sort(prices);
        if (n % 2 == 1) {
            median = prices[n / 2];
        } else {
            // Both values fit in 128 bits, so the sum cannot overflow.
            median = (prices[n / 2 - 1] + prices[n / 2]) / 2;
        }

        // Count how many fresh reports sit inside the deviation band around the median.
        uint256 band = median * maxDeviationBps;
        uint256 agreeing;
        for (uint256 i = 0; i < n; i++) {
            uint256 diff = prices[i] > median ? prices[i] - median : median - prices[i];
            if (diff * BPS <= band) agreeing++;
        }
        if (agreeing < minReports) return (2, 0);
    }

    function _freshPrices() internal view returns (uint256[] memory prices) {
        uint256 total = _reporters.length;
        uint256[] memory buf = new uint256[](total);
        uint256 n;
        for (uint256 i = 0; i < total; i++) {
            Report memory r = reports[_reporters[i]];
            // updatedAt <= block.timestamp always holds; written as an addition so that it
            // cannot underflow.
            if (r.updatedAt != 0 && uint256(r.updatedAt) + maxAge >= block.timestamp) {
                buf[n++] = r.price;
            }
        }
        prices = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            prices[i] = buf[i];
        }
    }

    /// @dev Insertion sort; the array holds at most MAX_REPORTERS elements.
    function _sort(uint256[] memory a) internal pure {
        for (uint256 i = 1; i < a.length; i++) {
            uint256 key = a[i];
            uint256 j = i;
            while (j > 0 && a[j - 1] > key) {
                a[j] = a[j - 1];
                j--;
            }
            a[j] = key;
        }
    }
}

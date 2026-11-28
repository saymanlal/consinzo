// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IQuoteToken {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Funding ledger of a perpetual market (no price or PnL, funding only).
contract FundingLedger {
    struct Position {
        int256 size; // base units (1e18 = one contract); positive long, negative short
        uint256 margin; // quote tokens
        int256 entryFundingIndex; // index of the position's side at the last settlement
    }

    error NotOwner();
    error ZeroAmount();
    error InsufficientMargin();
    error TransferFailed();

    event FundingAccrued(int256 cumulativeFundingLong, int256 cumulativeFundingShort);
    event FundingSettled(address indexed user, int256 owed);
    event PositionModified(address indexed user, int256 newSize);

    uint256 public constant WAD = 1e18;

    address public immutable owner;
    IQuoteToken public immutable quote;
    /// quote tokens of margin required per whole unit of |size| (WAD)
    uint256 public immutable minMarginPerUnit;

    /// quote paid by longs per unit of size per second (WAD). Negative: shorts pay.
    int256 public fundingRatePerSecond;
    uint256 public lastAccrual;
    int256 public cumulativeFundingLong;
    int256 public cumulativeFundingShort;
    uint256 public longOpenInterest;
    uint256 public shortOpenInterest;
    /// funding that payers owed but could not cover with their margin
    uint256 public shortfall;

    mapping(address => Position) public positions;

    constructor(IQuoteToken quote_, uint256 minMarginPerUnit_) {
        owner = msg.sender;
        quote = quote_;
        minMarginPerUnit = minMarginPerUnit_;
        lastAccrual = block.timestamp;
    }

    // ------------------------------------------------------------ funding

    function setFundingRate(int256 newRatePerSecond) external {
        if (msg.sender != owner) revert NotOwner();
        accrue();
        fundingRatePerSecond = newRatePerSecond;
    }

    function currentIndices() public view returns (int256 longIndex, int256 shortIndex) {
        longIndex = cumulativeFundingLong;
        shortIndex = cumulativeFundingShort;
        uint256 elapsed = block.timestamp - lastAccrual;
        int256 rate = fundingRatePerSecond;
        // With one side empty there is nobody to pay or nobody to receive: no funding.
        if (elapsed == 0 || rate == 0 || longOpenInterest == 0 || shortOpenInterest == 0) {
            return (longIndex, shortIndex);
        }
        if (rate > 0) {
            uint256 perUnit = uint256(rate) * elapsed;
            uint256 total = (longOpenInterest * perUnit) / WAD;
            longIndex += int256(perUnit);
            shortIndex -= int256((total * WAD) / shortOpenInterest);
        } else {
            uint256 perUnit = uint256(-rate) * elapsed;
            uint256 total = (shortOpenInterest * perUnit) / WAD;
            shortIndex += int256(perUnit);
            longIndex -= int256((total * WAD) / longOpenInterest);
        }
    }

    function accrue() public {
        if (block.timestamp == lastAccrual) return;
        (cumulativeFundingLong, cumulativeFundingShort) = currentIndices();
        lastAccrual = block.timestamp;
        emit FundingAccrued(cumulativeFundingLong, cumulativeFundingShort);
    }

    function pendingFunding(address user) public view returns (int256 owed) {
        (int256 longIndex, int256 shortIndex) = currentIndices();
        Position memory p = positions[user];
        if (p.size == 0) return 0;
        if (p.size > 0) {
            return _owed(uint256(p.size), longIndex - p.entryFundingIndex);
        }
        return _owed(uint256(-p.size), shortIndex - p.entryFundingIndex);
    }

    function settle(address user) external {
        accrue();
        _settle(user);
    }

    // ------------------------------------------------------------ user actions

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        accrue();
        _settle(msg.sender);
        positions[msg.sender].margin += amount;
        if (!quote.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        accrue();
        _settle(msg.sender);
        Position storage p = positions[msg.sender];
        if (amount > p.margin) revert InsufficientMargin();
        p.margin -= amount;
        _requireMargin(p);
        if (!quote.transfer(msg.sender, amount)) revert TransferFailed();
    }

    function modifyPosition(int256 sizeDelta) external {
        if (sizeDelta == 0) revert ZeroAmount();
        accrue();
        _settle(msg.sender);
        Position storage p = positions[msg.sender];

        if (p.size > 0) longOpenInterest -= uint256(p.size);
        else if (p.size < 0) shortOpenInterest -= uint256(-p.size);

        int256 newSize = p.size + sizeDelta;
        p.size = newSize;
        if (newSize > 0) {
            longOpenInterest += uint256(newSize);
            p.entryFundingIndex = cumulativeFundingLong;
        } else if (newSize < 0) {
            shortOpenInterest += uint256(-newSize);
            p.entryFundingIndex = cumulativeFundingShort;
        } else {
            p.entryFundingIndex = 0;
        }
        _requireMargin(p);
        emit PositionModified(msg.sender, newSize);
    }

    /// @dev Positive result: the position pays, rounded up. Negative: it receives, rounded down.
    function _owed(uint256 absSize, int256 indexDelta) internal pure returns (int256) {
        if (indexDelta >= 0) {
            return int256((absSize * uint256(indexDelta) + WAD - 1) / WAD);
        }
        return -int256((absSize * uint256(-indexDelta)) / WAD);
    }
    /// @dev Must be called after accrue(), so the stored indices are current.
    function _settle(address user) internal {
        Position storage p = positions[user];
        if (p.size == 0) return;
        int256 index = p.size > 0 ? cumulativeFundingLong : cumulativeFundingShort;
        int256 owed = _owed(uint256(p.size > 0 ? p.size : -p.size), index - p.entryFundingIndex);
        p.entryFundingIndex = index;
        if (owed > 0) {
            uint256 pay = uint256(owed);
            if (pay > p.margin) {
                // The receivers were already credited through their index: record the hole.
                shortfall += pay - p.margin;
                p.margin = 0;
            } else {
                p.margin -= pay;
            }
        } else if (owed < 0) {
            p.margin += uint256(-owed);
        }
        emit FundingSettled(user, owed);
    }
    function _requireMargin(Position storage p) internal view {
        uint256 absSize = uint256(p.size > 0 ? p.size : -p.size);
        if (p.margin * WAD < absSize * minMarginPerUnit) revert InsufficientMargin();
    }
}

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
        // TODO: owner only; accrue at the old rate first, then store the new rate.
        revert("NOT_IMPLEMENTED");
    }

    function currentIndices() public view returns (int256 longIndex, int256 shortIndex) {
        // TODO: the two cumulative indices extended to block.timestamp (see README, "Accrual").
        revert("NOT_IMPLEMENTED");
    }

    function accrue() public {
        // TODO: store currentIndices(), set lastAccrual = block.timestamp, emit FundingAccrued
        //       (only when time has passed).
        revert("NOT_IMPLEMENTED");
    }

    function pendingFunding(address user) public view returns (int256 owed) {
        // TODO: funding the position owes (positive, rounded up) or is owed (negative,
        //       magnitude rounded down), using currentIndices().
        revert("NOT_IMPLEMENTED");
    }

    function settle(address user) external {
        // TODO: accrue, then apply the user's pending funding to its margin (anyone may call).
        revert("NOT_IMPLEMENTED");
    }

    // ------------------------------------------------------------ user actions

    function deposit(uint256 amount) external {
        // TODO: ZeroAmount; accrue and settle the caller; pull quote tokens; credit margin.
        revert("NOT_IMPLEMENTED");
    }

    function withdraw(uint256 amount) external {
        // TODO: ZeroAmount; accrue and settle the caller; InsufficientMargin if the margin is
        //       too small or the remaining margin does not cover the requirement; pay out.
        revert("NOT_IMPLEMENTED");
    }

    function modifyPosition(int256 sizeDelta) external {
        // TODO: ZeroAmount; accrue and settle the caller at the old size; move the old size out
        //       of its side's open interest and the new size into its side; set the entry
        //       index to the current index of the new side (0 when flat); check the margin
        //       requirement; emit PositionModified.
        revert("NOT_IMPLEMENTED");
    }
}

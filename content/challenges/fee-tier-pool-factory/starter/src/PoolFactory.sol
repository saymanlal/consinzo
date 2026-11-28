// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal ERC-20 surface used by the pool. Provided; do not change.
interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Constant-product pool with a fixed fee tier and a segregated protocol fee balance.
contract FeePool {
    error NotFactory();
    error InvalidToken();
    error ZeroAmount();
    error ZeroLiquidity();
    error InsufficientLiquidity();
    error InsufficientOutput();

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, uint256 feeAmount, uint256 protocolCut);
    event ProtocolFeesCollected(address indexed to, uint256 amount0, uint256 amount1);

    uint256 public constant FEE_DENOMINATOR = 1_000_000;
    uint256 public constant BPS = 10_000;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable fee;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityOf;

    uint256 public protocolFees0;
    uint256 public protocolFees1;
    uint256 public totalFees0;
    uint256 public totalFees1;

    constructor(address token0_, address token1_, uint24 fee_) {
        factory = msg.sender;
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity) {
        // TODO: compute liquidity (sqrt for the first deposit, min of the two ratios after),
        //       revert with ZeroLiquidity on 0, update reserves and balances, pull both tokens.
        amount0; amount1; liquidity;
        revert("NOT_IMPLEMENTED");
    }

    function removeLiquidity(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1) {
        // TODO: validate, pay out the pro-rata share of the RESERVES only (never the protocol fees).
        liquidity; to; amount0; amount1;
        revert("NOT_IMPLEMENTED");
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut)
    {
        // TODO: split amountIn into netIn, liquidity-provider fee and protocol cut as described
        //       in the README, price with the pre-swap reserves, update the books, move tokens.
        tokenIn; amountIn; minAmountOut; to; amountOut;
        revert("NOT_IMPLEMENTED");
    }

    function collectProtocolFees(address to) external returns (uint256 amount0, uint256 amount1) {
        // TODO: factory only. Transfer and reset both protocol balances.
        to; amount0; amount1;
        revert("NOT_IMPLEMENTED");
    }

    /// @dev Babylonian square root, rounds down.
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        y = x;
        uint256 z = (x + 1) / 2;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

/// @title Deploys one FeePool per (unordered pair, fee tier).
contract PoolFactory {
    error NotOwner();
    error InvalidFee();
    error TierAlreadyEnabled();
    error TierNotEnabled();
    error IdenticalTokens();
    error ZeroAddress();
    error PoolExists();
    error InvalidProtocolFee();
    error UnknownPool();

    event FeeTierEnabled(uint24 fee);
    event ProtocolFeeChanged(uint16 bps);
    event PoolCreated(address indexed token0, address indexed token1, uint24 indexed fee, address pool);

    uint24 public constant MAX_FEE = 100_000;
    uint16 public constant MAX_PROTOCOL_FEE_BPS = 2_500;

    address public immutable owner;
    uint16 public protocolFeeBps;

    mapping(uint24 => bool) public feeTierEnabled;
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;
    mapping(address => bool) public isPool;
    address[] public allPools;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
        _enable(500);
        _enable(3000);
        _enable(10000);
    }

    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    function enableFeeTier(uint24 fee) external onlyOwner {
        // TODO: validate 0 < fee < MAX_FEE and that the tier is new, then enable it.
        fee;
        revert("NOT_IMPLEMENTED");
    }

    function setProtocolFeeBps(uint16 bps) external onlyOwner {
        // TODO: enforce the cap and store the value.
        bps;
        revert("NOT_IMPLEMENTED");
    }

    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool) {
        // TODO: run the checks in the documented order, sort the tokens, deploy a FeePool and
        //       register it under both key orders, in isPool and in allPools.
        tokenA; tokenB; fee; pool;
        revert("NOT_IMPLEMENTED");
    }

    function collectProtocolFees(address pool, address to)
        external
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        // TODO: reject unknown pools and forward to the pool.
        pool; to; amount0; amount1;
        revert("NOT_IMPLEMENTED");
    }

    function _enable(uint24 fee) internal {
        feeTierEnabled[fee] = true;
        emit FeeTierEnabled(fee);
    }
}

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
        uint256 total = totalLiquidity;
        if (total == 0) {
            liquidity = _sqrt(amount0 * amount1);
        } else {
            uint256 l0 = (amount0 * total) / reserve0;
            uint256 l1 = (amount1 * total) / reserve1;
            liquidity = l0 < l1 ? l0 : l1;
        }
        if (liquidity == 0) revert ZeroLiquidity();

        reserve0 += amount0;
        reserve1 += amount1;
        totalLiquidity = total + liquidity;
        liquidityOf[msg.sender] += liquidity;

        IERC20Like(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20Like(token1).transferFrom(msg.sender, address(this), amount1);
        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert ZeroAmount();
        if (liquidityOf[msg.sender] < liquidity) revert InsufficientLiquidity();

        uint256 total = totalLiquidity;
        // Only the reserves are shared out. The protocol balances sit in the same token
        // balance but belong to the factory owner.
        amount0 = (liquidity * reserve0) / total;
        amount1 = (liquidity * reserve1) / total;

        liquidityOf[msg.sender] -= liquidity;
        totalLiquidity = total - liquidity;
        reserve0 -= amount0;
        reserve1 -= amount1;

        IERC20Like(token0).transfer(to, amount0);
        IERC20Like(token1).transfer(to, amount1);
        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut)
    {
        bool zeroForOne = tokenIn == token0;
        if (!zeroForOne && tokenIn != token1) revert InvalidToken();
        if (amountIn == 0) revert ZeroAmount();

        uint256 feeAmount = (amountIn * fee) / FEE_DENOMINATOR;
        uint256 protocolCut = (feeAmount * PoolFactory(factory).protocolFeeBps()) / BPS;
        uint256 netIn = amountIn - feeAmount;

        (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);
        amountOut = (netIn * reserveOut) / (reserveIn + netIn);
        if (amountOut == 0 || amountOut < minAmountOut) revert InsufficientOutput();

        // The liquidity-provider part of the fee joins the reserve; the protocol cut does not.
        reserveIn += amountIn - protocolCut;
        reserveOut -= amountOut;

        if (zeroForOne) {
            (reserve0, reserve1) = (reserveIn, reserveOut);
            protocolFees0 += protocolCut;
            totalFees0 += feeAmount;
        } else {
            (reserve1, reserve0) = (reserveIn, reserveOut);
            protocolFees1 += protocolCut;
            totalFees1 += feeAmount;
        }

        IERC20Like(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20Like(zeroForOne ? token1 : token0).transfer(to, amountOut);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut, feeAmount, protocolCut);
    }

    function collectProtocolFees(address to) external returns (uint256 amount0, uint256 amount1) {
        if (msg.sender != factory) revert NotFactory();
        amount0 = protocolFees0;
        amount1 = protocolFees1;
        protocolFees0 = 0;
        protocolFees1 = 0;
        if (amount0 > 0) IERC20Like(token0).transfer(to, amount0);
        if (amount1 > 0) IERC20Like(token1).transfer(to, amount1);
        emit ProtocolFeesCollected(to, amount0, amount1);
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
        if (fee == 0 || fee >= MAX_FEE) revert InvalidFee();
        if (feeTierEnabled[fee]) revert TierAlreadyEnabled();
        _enable(fee);
    }

    function setProtocolFeeBps(uint16 bps) external onlyOwner {
        if (bps > MAX_PROTOCOL_FEE_BPS) revert InvalidProtocolFee();
        protocolFeeBps = bps;
        emit ProtocolFeeChanged(bps);
    }

    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool) {
        if (tokenA == tokenB) revert IdenticalTokens();
        // Sorting first makes (A, B) and (B, A) the same key everywhere below.
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
        if (!feeTierEnabled[fee]) revert TierNotEnabled();
        if (getPool[token0][token1][fee] != address(0)) revert PoolExists();

        pool = address(new FeePool(token0, token1, fee));
        getPool[token0][token1][fee] = pool;
        getPool[token1][token0][fee] = pool;
        isPool[pool] = true;
        allPools.push(pool);
        emit PoolCreated(token0, token1, fee, pool);
    }

    function collectProtocolFees(address pool, address to)
        external
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        if (!isPool[pool]) revert UnknownPool();
        return FeePool(pool).collectProtocolFees(to);
    }

    function _enable(uint24 fee) internal {
        feeTierEnabled[fee] = true;
        emit FeeTierEnabled(fee);
    }
}

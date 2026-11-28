// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice Minimal token interface used by the pair. Provided; do not edit.
interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title Constant-product pair with a protocol fee switch (kLast accounting).
contract FeeSwitchPair {
    error NotOwner();
    error InvalidToken();
    error ZeroAmount();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidity();
    error InsufficientOutput();

    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
    event Swap(address indexed sender, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed to);
    event ProtocolFeeMinted(address indexed feeTo, uint256 liquidity);

    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public immutable owner;
    address public immutable token0;
    address public immutable token1;
    address public feeTo;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public kLast;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address token0_, address token1_) {
        owner = msg.sender;
        token0 = token0_;
        token1 = token1_;
    }

    function setFeeTo(address newFeeTo) external {
        if (msg.sender != owner) revert NotOwner();
        feeTo = newFeeTo;
    }

    function mint(uint256 amount0, uint256 amount1, address to) external returns (uint256 liquidity) {
        bool feeOn = _mintFee();
        uint256 supply = totalSupply; // read after _mintFee: protocol shares dilute first
        if (supply == 0) {
            uint256 root = _sqrt(amount0 * amount1);
            if (root <= MINIMUM_LIQUIDITY) revert InsufficientLiquidityMinted();
            liquidity = root - MINIMUM_LIQUIDITY;
            _mintShares(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint256 l0 = (amount0 * supply) / reserve0;
            uint256 l1 = (amount1 * supply) / reserve1;
            liquidity = l0 < l1 ? l0 : l1;
            if (liquidity == 0) revert InsufficientLiquidityMinted();
        }

        reserve0 += amount0;
        reserve1 += amount1;
        _mintShares(to, liquidity);
        if (feeOn) kLast = reserve0 * reserve1;

        IERC20Like(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20Like(token1).transferFrom(msg.sender, address(this), amount1);
        emit Mint(msg.sender, amount0, amount1, liquidity, to);
    }

    function burn(uint256 liquidity, address to) external returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < liquidity) revert InsufficientLiquidity();
        bool feeOn = _mintFee();
        uint256 supply = totalSupply;
        amount0 = (liquidity * reserve0) / supply;
        amount1 = (liquidity * reserve1) / supply;

        balanceOf[msg.sender] -= liquidity;
        totalSupply = supply - liquidity;
        reserve0 -= amount0;
        reserve1 -= amount1;
        if (feeOn) kLast = reserve0 * reserve1;

        IERC20Like(token0).transfer(to, amount0);
        IERC20Like(token1).transfer(to, amount1);
        emit Burn(msg.sender, amount0, amount1, liquidity, to);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to)
        external
        returns (uint256 amountOut)
    {
        bool zeroForOne = tokenIn == token0;
        if (!zeroForOne && tokenIn != token1) revert InvalidToken();
        if (amountIn == 0) revert ZeroAmount();

        (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 inWithFee = amountIn * 997;
        amountOut = (inWithFee * reserveOut) / (reserveIn * 1000 + inWithFee);
        if (amountOut == 0 || amountOut < minAmountOut) revert InsufficientOutput();

        if (zeroForOne) {
            reserve0 = reserveIn + amountIn;
            reserve1 = reserveOut - amountOut;
        } else {
            reserve1 = reserveIn + amountIn;
            reserve0 = reserveOut - amountOut;
        }

        IERC20Like(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20Like(zeroForOne ? token1 : token0).transfer(to, amountOut);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut, to);
    }

    /// @dev Mints shares worth one sixth of the growth in sqrt(k) to feeTo. With S the supply,
    ///      minting S * (rootK - rootKLast) / (5 * rootK + rootKLast) new shares gives the
    ///      recipient exactly 1/6 of the fee growth after dilution.
    function _mintFee() internal returns (bool feeOn) {
        address recipient = feeTo;
        feeOn = recipient != address(0);
        uint256 last = kLast;
        if (feeOn) {
            if (last != 0) {
                uint256 rootK = _sqrt(reserve0 * reserve1);
                uint256 rootKLast = _sqrt(last);
                if (rootK > rootKLast) {
                    uint256 liquidity = (totalSupply * (rootK - rootKLast)) / (rootK * 5 + rootKLast);
                    if (liquidity > 0) {
                        _mintShares(recipient, liquidity);
                        emit ProtocolFeeMinted(recipient, liquidity);
                    }
                }
            }
        } else if (last != 0) {
            // Growth earned while the switch is off must never be charged later.
            kLast = 0;
        }
    }

    function _mintShares(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

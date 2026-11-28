// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @notice Source-chain side: custody of the canonical token.
contract SourceVault {
    IERC20Like public immutable token;
    address public immutable relayer;

    uint256 public depositCount;
    uint256 public totalLocked;
    mapping(uint256 => bool) public processedBurns;

    event Locked(uint256 indexed depositNonce, address indexed sender, address indexed recipient, uint256 amount);
    event Released(uint256 indexed burnNonce, address indexed recipient, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error NotRelayer();
    error AlreadyProcessed();
    error InsufficientLocked();
    error TransferFailed();

    constructor(address token_, address relayer_) {
        if (token_ == address(0) || relayer_ == address(0)) revert ZeroAddress();
        token = IERC20Like(token_);
        relayer = relayer_;
    }

    function lock(uint256 amount, address recipient) external returns (uint256 depositNonce) {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        depositNonce = ++depositCount;
        totalLocked += amount;
        emit Locked(depositNonce, msg.sender, recipient, amount);

        if (!token.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
    }

    function release(uint256 burnNonce, address recipient, uint256 amount) external {
        if (msg.sender != relayer) revert NotRelayer();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (processedBurns[burnNonce]) revert AlreadyProcessed();
        // Accounting is against totalLocked, not the raw balance, so donations to the
        // vault can never back a release that no burn justified.
        if (amount > totalLocked) revert InsufficientLocked();

        // Effects before the external call: a replay through a callback finds the nonce used.
        processedBurns[burnNonce] = true;
        totalLocked -= amount;
        emit Released(burnNonce, recipient, amount);

        if (!token.transfer(recipient, amount)) revert TransferFailed();
    }
}

/// @notice Destination-chain side: wrapped ERC-20 minted and burned 1:1 against the vault.
contract WrappedToken {
    string public constant name = "Wrapped Bridged Token";
    string public constant symbol = "wBRG";
    uint8 public constant decimals = 18;

    address public immutable relayer;

    uint256 public totalSupply;
    uint256 public burnCount;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(uint256 => bool) public processedDeposits;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Minted(uint256 indexed depositNonce, address indexed to, uint256 amount);
    event Burned(uint256 indexed burnNonce, address indexed sender, address indexed recipient, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error NotRelayer();
    error AlreadyProcessed();
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(address relayer_) {
        if (relayer_ == address(0)) revert ZeroAddress();
        relayer = relayer_;
    }

    function mint(uint256 depositNonce, address to, uint256 amount) external {
        if (msg.sender != relayer) revert NotRelayer();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (processedDeposits[depositNonce]) revert AlreadyProcessed();

        processedDeposits[depositNonce] = true;
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Minted(depositNonce, to, amount);
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount, address recipient) external returns (uint256 burnNonce) {
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[msg.sender];
        if (bal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[msg.sender] = bal - amount;
        }
        totalSupply -= amount;
        burnNonce = ++burnCount;
        emit Burned(burnNonce, msg.sender, recipient, amount);
        emit Transfer(msg.sender, address(0), amount);
    }

    // ------------------------------------------------------------------ ERC-20 plumbing

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance();
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance();
        unchecked {
            balanceOf[from] = bal - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// @notice ETH treasury operated under dual control.
/// Sensitive actions need an officer who holds BOTH the treasurer and the compliance role.
contract DualControlTreasury {
    error NotOwner();
    error Unauthorized();
    error TreasuryPaused();
    error NotPaused();
    error ZeroAddress();
    error OverLimit();
    error TransferFailed();

    event RoleSet(bytes32 indexed role, address indexed account, bool enabled);
    event PaymentExecuted(address indexed officer, address indexed to, uint256 amount);
    event PausedSet(address indexed by, bool paused);
    event PaymentLimitSet(address indexed by, uint256 newLimit);

    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    address public immutable owner;
    bool public paused;
    uint256 public paymentLimit;
    mapping(bytes32 => mapping(address => bool)) public hasRole;

    constructor(uint256 _paymentLimit) payable {
        owner = msg.sender;
        paymentLimit = _paymentLimit;
    }

    receive() external payable {}

    function setRole(bytes32 role, address account, bool enabled) external {
        if (msg.sender != owner) revert NotOwner();
        if (account == address(0)) revert ZeroAddress();
        hasRole[role][account] = enabled;
        emit RoleSet(role, account, enabled);
    }

    /// @notice Send `amount` wei to `to`. Requires BOTH roles.
    function executePayment(address payable to, uint256 amount) external {
        if (!_hasBoth(msg.sender)) revert Unauthorized();
        if (paused) revert TreasuryPaused();
        if (to == address(0)) revert ZeroAddress();
        if (amount > paymentLimit) revert OverLimit();

        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit PaymentExecuted(msg.sender, to, amount);
    }

    /// @notice Emergency stop. EITHER role may pause.
    function pause() external {
        // Deliberately the weaker check: stopping the treasury must be easy.
        if (!_hasEither(msg.sender)) revert Unauthorized();
        paused = true;
        emit PausedSet(msg.sender, true);
    }

    /// @notice Resume payments. Requires BOTH roles.
    function unpause() external {
        if (!_hasBoth(msg.sender)) revert Unauthorized();
        if (!paused) revert NotPaused();
        paused = false;
        emit PausedSet(msg.sender, false);
    }

    /// @notice Change the per-payment limit. Allowed for the owner, or for an officer with BOTH roles.
    function setPaymentLimit(uint256 newLimit) external {
        if (msg.sender != owner && !_hasBoth(msg.sender)) revert Unauthorized();
        paymentLimit = newLimit;
        emit PaymentLimitSet(msg.sender, newLimit);
    }

    /// @dev Positive predicates keep each guard readable as `if (!allowed) revert`,
    /// which avoids hand-negating a compound condition at every call site.
    function _hasBoth(address account) internal view returns (bool) {
        return hasRole[TREASURER_ROLE][account] && hasRole[COMPLIANCE_ROLE][account];
    }

    function _hasEither(address account) internal view returns (bool) {
        return hasRole[TREASURER_ROLE][account] || hasRole[COMPLIANCE_ROLE][account];
    }
}

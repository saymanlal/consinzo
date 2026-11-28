// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/// Management functions of the proxy. They are only reachable for the admin.
interface ITransparentProxy {
    function admin() external returns (address);
    function implementation() external returns (address);
    function changeAdmin(address newAdmin) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract TransparentProxy {
    error NotContract(address target);
    error ZeroAdmin();
    error AdminCannotFallback();

    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address implementation_, address admin_, bytes memory initData) payable {
        // TODO: validate, store both addresses in their EIP-1967 slots,
        //       delegatecall initData when it is not empty (bubble up reverts).
    }

    fallback() external payable {
        // TODO: if msg.sender is the admin, dispatch on msg.sig to the five management
        //       functions and revert with AdminCannotFallback for anything else.
        // TODO: otherwise delegate the call to the implementation and pass the result through.
        revert("NOT_IMPLEMENTED");
    }
}

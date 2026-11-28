// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Create3Deployer {
    error ProxyDeploymentFailed();
    error DeploymentFailed();

    event Deployed(address indexed sender, bytes32 indexed salt, address deployed);

    /// Init code of the proxy. Runtime code 0x363d3d37363d34f0:
    /// calldatacopy(0, 0, calldatasize()); create(callvalue(), 0, calldatasize())
    bytes internal constant PROXY_INITCODE = hex"67363d3d37363d34f03d5260086018f3";

    function deploy(bytes32 salt, bytes calldata initCode) external payable returns (address deployed) {
        // TODO: CREATE2 the proxy with a salt bound to msg.sender (ProxyDeploymentFailed).
        // TODO: call the proxy with initCode and msg.value.
        // TODO: verify that code exists at the final address (DeploymentFailed), emit Deployed.
        revert("NOT_IMPLEMENTED");
    }

    function addressOf(address sender, bytes32 salt) external view returns (address) {
        // TODO: address created by the proxy at nonce 1.
        revert("NOT_IMPLEMENTED");
    }

    function proxyAddressOf(address sender, bytes32 salt) external view returns (address) {
        // TODO: CREATE2 address of the proxy.
        revert("NOT_IMPLEMENTED");
    }
}

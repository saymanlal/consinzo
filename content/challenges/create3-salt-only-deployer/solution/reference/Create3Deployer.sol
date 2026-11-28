// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract Create3Deployer {
    error ProxyDeploymentFailed();
    error DeploymentFailed();

    event Deployed(address indexed sender, bytes32 indexed salt, address deployed);

    /// Init code of the proxy. Runtime code 0x363d3d37363d34f0:
    /// calldatacopy(0, 0, calldatasize()); create(callvalue(), 0, calldatasize())
    bytes internal constant PROXY_INITCODE = hex"67363d3d37363d34f03d5260086018f3";
    bytes32 internal constant PROXY_INITCODE_HASH = keccak256(PROXY_INITCODE);

    function deploy(bytes32 salt, bytes calldata initCode) external payable returns (address deployed) {
        bytes32 create2Salt = _create2Salt(msg.sender, salt);
        bytes memory proxyCode = PROXY_INITCODE;

        address proxy;
        assembly {
            proxy := create2(0, add(proxyCode, 0x20), mload(proxyCode), create2Salt)
        }
        // CREATE2 returns zero when a contract already exists at the target address.
        if (proxy == address(0)) revert ProxyDeploymentFailed();

        deployed = _createdBy(proxy);
        // The proxy forwards the value into CREATE. It does not revert when the creation
        // fails, so success of this call alone proves nothing.
        (bool ok,) = proxy.call{value: msg.value}(initCode);
        if (!ok || deployed.code.length == 0) revert DeploymentFailed();

        emit Deployed(msg.sender, salt, deployed);
    }

    function addressOf(address sender, bytes32 salt) external view returns (address) {
        return _createdBy(_proxyAddress(sender, salt));
    }

    function proxyAddressOf(address sender, bytes32 salt) external view returns (address) {
        return _proxyAddress(sender, salt);
    }

    /// Binding the salt to the caller prevents others from occupying a caller's addresses.
    function _create2Salt(address sender, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(sender, salt));
    }

    function _proxyAddress(address sender, bytes32 salt) private view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), address(this), _create2Salt(sender, salt), PROXY_INITCODE_HASH)
                    )
                )
            )
        );
    }

    /// Address of the first contract created by `proxy`: rlp([proxy, 1]) hashed.
    /// 0xd6 = 0xc0 + 22 payload bytes, 0x94 = 0x80 + 20 address bytes, nonce 1 = 0x01.
    function _createdBy(address proxy) private pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", proxy, hex"01")))));
    }
}

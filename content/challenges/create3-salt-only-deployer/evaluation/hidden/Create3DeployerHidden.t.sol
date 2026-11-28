// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Create3Deployer.sol";

contract Vaultlet {
    address public creator;
    uint256 public endowment;
    uint256 public a;
    bytes32 public b;

    constructor(uint256 a_, bytes32 b_) payable {
        creator = msg.sender;
        endowment = msg.value;
        a = a_;
        b = b_;
    }
}

contract AlwaysReverts {
    error Nope();

    constructor() {
        revert Nope();
    }
}

contract Plain {
    function ping() external pure returns (uint256) {
        return 1;
    }
}

contract Create3DeployerHiddenTest is Test {
    bytes internal constant PROXY_INITCODE = hex"67363d3d37363d34f03d5260086018f3";

    Create3Deployer public deployer;
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    function setUp() public {
        deployer = new Create3Deployer();
    }

    function _expectedProxy(address sender, bytes32 salt) internal view returns (address) {
        bytes32 create2Salt = keccak256(abi.encodePacked(sender, salt));
        return address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(deployer), create2Salt, keccak256(PROXY_INITCODE)))
                )
            )
        );
    }

    function _expectedFinal(address proxy) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), proxy, bytes1(0x01))))));
    }

    function testHiddenDerivationFormulas() public view {
        bytes32[3] memory salts = [bytes32(0), keccak256("x"), bytes32(type(uint256).max)];
        for (uint256 i = 0; i < 3; i++) {
            address proxy = _expectedProxy(alice, salts[i]);
            assertEq(deployer.proxyAddressOf(alice, salts[i]), proxy);
            assertEq(deployer.addressOf(alice, salts[i]), _expectedFinal(proxy));
        }
        assertNotEq(deployer.addressOf(alice, salts[0]), deployer.addressOf(alice, salts[1]));
    }

    function testHiddenProxyIsDeployedWithExpectedRuntime() public {
        bytes32 salt = keccak256("proxy");
        vm.prank(alice);
        address deployed = deployer.deploy(salt, type(Plain).creationCode);

        address proxy = deployer.proxyAddressOf(alice, salt);
        assertEq(keccak256(proxy.code), keccak256(hex"363d3d37363d34f0"));
        assertEq(deployed, _expectedFinal(proxy));
        assertEq(Plain(deployed).ping(), 1);
    }

    function testHiddenValueAndArgumentsReachConstructor() public {
        bytes32 salt = keccak256("value");
        bytes memory initCode =
            abi.encodePacked(type(Vaultlet).creationCode, abi.encode(uint256(123), keccak256("arg")));

        vm.deal(alice, 5 ether);
        vm.prank(alice);
        address deployed = deployer.deploy{value: 3 ether}(salt, initCode);

        Vaultlet v = Vaultlet(deployed);
        assertEq(v.endowment(), 3 ether);
        assertEq(deployed.balance, 3 ether);
        assertEq(address(deployer).balance, 0);
        assertEq(deployer.proxyAddressOf(alice, salt).balance, 0);
        assertEq(v.a(), 123);
        assertEq(v.b(), keccak256("arg"));
        // The constructor sees the proxy as msg.sender, not the deployer or the user.
        assertEq(v.creator(), deployer.proxyAddressOf(alice, salt));
    }

    function testHiddenRevertingConstructorIsDetectedAndSaltStaysFree() public {
        bytes32 salt = keccak256("revert");
        vm.expectRevert(Create3Deployer.DeploymentFailed.selector);
        deployer.deploy(salt, type(AlwaysReverts).creationCode);

        assertEq(deployer.addressOf(address(this), salt).code.length, 0);
        assertEq(deployer.proxyAddressOf(address(this), salt).code.length, 0);

        // Nothing was left behind, so the salt still works.
        address deployed = deployer.deploy(salt, type(Plain).creationCode);
        assertEq(deployed, deployer.addressOf(address(this), salt));
        assertEq(Plain(deployed).ping(), 1);
    }

    function testHiddenEmptyRuntimeCodeIsRejected() public {
        // Init code that returns zero bytes of runtime code: PUSH1 0 PUSH1 0 RETURN.
        vm.expectRevert(Create3Deployer.DeploymentFailed.selector);
        deployer.deploy(keccak256("empty-runtime"), hex"60006000f3");

        // Empty init code creates an account without code as well.
        vm.expectRevert(Create3Deployer.DeploymentFailed.selector);
        deployer.deploy(keccak256("empty-init"), "");
    }

    function testHiddenFailedDeploymentRefundsNothingSilently() public {
        vm.deal(alice, 2 ether);
        vm.prank(alice);
        (bool ok,) = address(deployer).call{value: 2 ether}(
            abi.encodeCall(Create3Deployer.deploy, (keccak256("v"), type(AlwaysReverts).creationCode))
        );
        assertFalse(ok);
        // The whole call reverted, so the value never left the caller.
        assertEq(alice.balance, 2 ether);
        assertEq(address(deployer).balance, 0);
    }

    function testHiddenFrontRunnerCannotTakeAddress() public {
        bytes32 salt = keccak256("shared-salt");
        address aliceTarget = deployer.addressOf(alice, salt);

        // Bob sees Alice's pending transaction and submits the same salt first.
        vm.prank(bob);
        address bobs = deployer.deploy(salt, type(Plain).creationCode);
        assertNotEq(bobs, aliceTarget);
        assertEq(aliceTarget.code.length, 0);

        vm.prank(alice);
        address alices = deployer.deploy(salt, abi.encodePacked(type(Vaultlet).creationCode, abi.encode(uint256(1), bytes32(0))));
        assertEq(alices, aliceTarget);

        // Each of them is now blocked from reusing the salt.
        vm.prank(bob);
        vm.expectRevert(Create3Deployer.ProxyDeploymentFailed.selector);
        deployer.deploy(salt, type(Plain).creationCode);
        vm.prank(alice);
        vm.expectRevert(Create3Deployer.ProxyDeploymentFailed.selector);
        deployer.deploy(salt, type(Plain).creationCode);
    }

    function testHiddenManySaltsAndSeparateDeployers() public {
        Create3Deployer other = new Create3Deployer();
        for (uint256 i = 0; i < 5; i++) {
            bytes32 salt = bytes32(i);
            address predicted = deployer.addressOf(address(this), salt);
            assertNotEq(predicted, other.addressOf(address(this), salt));
            assertEq(deployer.deploy(salt, type(Plain).creationCode), predicted);
        }
        // The same salt on another deployer instance is unaffected.
        assertEq(other.deploy(bytes32(0), type(Plain).creationCode), other.addressOf(address(this), bytes32(0)));
    }
}

// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../test/shared/EIP2470.t.sol";
import "../../src/BobToken.sol";
import "../../src/proxy/EIP1967Proxy.sol";

contract DeployBobToken is Script {
    address private constant deployer = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant minter = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant admin = 0xBF3d6f830CE263CAE987193982192Cd990442B53;

    address private constant vanityAddr = address(0xB0Bf1847E7CD691A2Dbc619a515FE2FaE8f69B0B);
    address private constant mockImpl = address(0xdead);
    bytes32 private constant salt = bytes32(uint256(17725258));

    SingletonFactory private constant factory = SingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);

    function run() external {
        require(tx.origin == deployer, "Script private key is different from deployer address");

        vm.startBroadcast();

        bytes memory creationCode =
            abi.encodePacked(type(EIP1967Proxy).creationCode, uint256(uint160(deployer)), uint256(uint160(mockImpl)));
        EIP1967Proxy proxy = EIP1967Proxy(factory.deploy(creationCode, salt));

        BobToken impl = new BobToken(address(proxy));

        proxy.upgradeTo(address(impl));

        BobToken bob = BobToken(address(proxy));
        bob.setMinter(minter);

        if (deployer != admin) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(address(bob) == vanityAddr, "Invalid vanity address");
        require(proxy.admin() == admin, "Invalid admin account");
        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(bob.minter() == minter, "Minter is not configured");
    }
}

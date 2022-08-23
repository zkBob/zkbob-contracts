// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../test/shared/EIP2470.t.sol";
import "../../src/BobToken.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/MultiMinter.sol";

contract DeployBobToken is Script {
    SingletonFactory private constant factory = SingletonFactory(0xce0042B868300000d44A59004Da54A005ffdcf9f);

    function run() external {
        require(tx.origin == deployer, "Script private key is different from deployer address");

        vm.startBroadcast();

        bytes memory creationCode = bytes.concat(type(EIP1967Proxy).creationCode, abi.encode(deployer, mockImpl, ""));
        EIP1967Proxy proxy = EIP1967Proxy(factory.deploy(creationCode, bobSalt));

        BobToken impl = new BobToken(address(proxy));

        proxy.upgradeTo(address(impl));

        BobToken bob = BobToken(address(proxy));

        MultiMinter minter = new MultiMinter(address(bob));

        bob.setMinter(address(minter));

        if (bobMinter != address(0)) {
            minter.setMinter(bobMinter, true);
        }

        if (owner != address(0)) {
            bob.transferOwnership(owner);
            minter.transferOwnership(owner);
        }

        if (admin != deployer) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(address(bob) == bobVanityAddr, "Invalid vanity address");
        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(proxy.admin() == admin, "Proxy admin is not configured");
        require(bob.owner() == owner, "Owner is not configured");
        require(bob.minter() == address(minter), "Minter is not configured");
        require(minter.owner() == owner, "Minter owner is not configured");
        require(bobMinter == address(0) || minter.minter(bobMinter), "Bob minter is not configured");
    }
}

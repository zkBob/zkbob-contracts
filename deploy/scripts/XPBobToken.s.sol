// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/XPBobToken.sol";
import "../../src/proxy/EIP1967Proxy.sol";

contract DeployXPBobToken is Script {
    address private constant minter = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant admin = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant owner = 0xBF3d6f830CE263CAE987193982192Cd990442B53;

    address private constant mockImpl = address(0xdead);

    function run() external {
        vm.startBroadcast();

        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, mockImpl);

        XPBobToken impl = new XPBobToken(address(proxy));

        proxy.upgradeTo(address(impl));

        XPBobToken vbob = XPBobToken(address(proxy));
        vbob.setMinter(minter);

        if (admin != owner) {
            vbob.transferOwnership(owner);
        }

        if (tx.origin != admin) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(proxy.admin() == admin, "Proxy admin is not configured");
        if (admin == owner) {
            require(vbob.owner() == address(0), "Owner is not configured");
        } else {
            require(vbob.owner() == owner, "Owner is not configured");
        }
        require(vbob.minter() == minter, "Minter is not configured");
    }
}

// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/XPBobToken.sol";
import "../../src/proxy/EIP1967Proxy.sol";

contract DeployXPBobToken is Script {
    function run() external {
        vm.startBroadcast();

        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, mockImpl, "");

        XPBobToken impl = new XPBobToken(address(proxy));

        proxy.upgradeTo(address(impl));

        XPBobToken xp = XPBobToken(address(proxy));
        if (xpMinter != address(0)) {
            xp.updateMinter(xpMinter, true, true);
        }

        if (owner != address(0)) {
            xp.transferOwnership(owner);
        }

        if (admin != tx.origin) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(proxy.admin() == admin, "Proxy admin is not configured");
        require(xp.owner() == owner, "Owner is not configured");
        require(xpMinter == address(0) || xp.isMinter(xpMinter), "Bob minter is not configured");

        console2.log("XPBobToken:", address(xp));
        console2.log("XPBobToken implementation:", address(impl));
    }
}

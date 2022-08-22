// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/proxy/EIP1967Proxy.sol";

contract DeployEIP1967Proxy is Script {
    address private constant admin = address(0);
    address private constant impl = address(0xdead);

    function run() external {
        vm.startBroadcast();

        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, impl, "");

        if (admin != address(0) && tx.origin != admin) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(proxy.admin() == admin == address(0) ? tx.origin : admin, "Proxy admin is not configured");
    }
}

// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/BobVault.sol";

contract DeployBobVault is Script {
    address private constant minter = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant admin = 0xBF3d6f830CE263CAE987193982192Cd990442B53;
    address private constant yieldAdmin = 0x0000000000000000000000000000000000000000;
    address private constant investAdmin = 0x0000000000000000000000000000000000000000;

    function run() external {
        vm.startBroadcast();

        BobVault impl = new BobVault();
        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, address(impl));

        BobVault vault = BobVault(address(proxy));

        if (yieldAdmin != address(0)) {
            vault.setYieldAdmin(yieldAdmin);
        }

        if (investAdmin != address(0)) {
            vault.setInvestAdmin(investAdmin);
        }

        if (tx.origin != admin) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(proxy.admin() == admin, "Invalid admin account");
        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(vault.yieldAdmin() == yieldAdmin, "Yield admin is not configured");
        require(vault.investAdmin() == investAdmin, "Invest admin is not configured");
    }
}

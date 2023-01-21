// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "./Env.s.sol";
import "../../src/proxy/EIP1967Proxy.sol";
import "../../src/BobVault.sol";
import "../../src/yield/AAVEYieldImplementation.sol";

contract DeployBobVault is Script {
    function run() external {
        vm.startBroadcast();

        BobVault impl = new BobVault(bobVanityAddr);
        EIP1967Proxy proxy = new EIP1967Proxy(tx.origin, address(impl), "");

        BobVault vault = BobVault(address(proxy));

        if (vaultYieldAdmin != address(0)) {
            vault.setYieldAdmin(vaultYieldAdmin);
        }

        if (vaultCollateralTokenAddress != address(0)) {
            address yield = address(0);
            if (vaultCollateralAAVELendingPool != address(0)) {
                yield = address(new AAVEYieldImplementation(vaultCollateralAAVELendingPool));
            } else {
                require(vaultCollateralBuffer == 0, "Buffer is non-zero");
                require(vaultCollateralDust == 0, "Dust is non-zero");
            }
            vault.addCollateral(
                vaultCollateralTokenAddress,
                BobVault.Collateral({
                    balance: 0,
                    buffer: vaultCollateralBuffer,
                    dust: vaultCollateralDust,
                    yield: yield,
                    price: vaultCollateralPrice,
                    inFee: vaultCollateralInFee,
                    outFee: vaultCollateralOutFee,
                    maxBalance: type(uint128).max,
                    maxInvested: type(uint128).max
                })
            );

            require(vault.isCollateral(vaultCollateralTokenAddress), "Collateral is not configured");
        }

        if (vaultInvestAdmin != address(0)) {
            vault.setInvestAdmin(vaultInvestAdmin);
        }

        if (owner != address(0)) {
            vault.transferOwnership(owner);
        }

        if (admin != deployer) {
            proxy.setAdmin(admin);
        }

        vm.stopBroadcast();

        require(proxy.implementation() == address(impl), "Invalid implementation address");
        require(proxy.admin() == admin, "Proxy admin is not configured");
        require(vault.owner() == owner, "Owner is not configured");
        require(vault.yieldAdmin() == vaultYieldAdmin, "Yield admin is not configured");
        require(vault.investAdmin() == vaultInvestAdmin, "Invest admin is not configured");
    }
}

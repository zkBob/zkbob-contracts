// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/zkbob/ZkBobPool.sol";

contract SetManagerAndTierLimits is Script {
    function run() external {
        ZkBobPool.Limits memory limits;
        ZkBobPool pool = ZkBobPool(0x3bd088C19960A8B5d72E4e01847791BD0DD1C9E6);

        //vm.startPrank(0x2d5C035F99a7DF3067EDAcDED0e117d7076aBf7c);
        vm.startBroadcast();

        pool.setLimits({
            _tier: 254,
            _tvlCap: 1000000 ether,
            _dailyDepositCap: 300000 ether,
            _dailyWithdrawalCap: 100000 ether,
            _dailyUserDepositCap: 20000 ether,
            _depositCap: 20000 ether,
            _dailyUserDirectDepositCap: 10000 ether,
            _directDepositCap: 1000 ether
        });

        pool.setKycProvidersManager(IKycProvidersManager(0x98DB3A72BeF2145A8F8d8B94F81317341Af2b08C));

        vm.stopBroadcast();
        //vm.stopPrank();

        require(pool.kycProvidersManager() == IKycProvidersManager(0x98DB3A72BeF2145A8F8d8B94F81317341Af2b08C), "Incorrect KYC Provider Manager");

        limits = pool.getLimitsFor(0x84E94F8032b3F9fEc34EE05F192Ad57003337988);
        require((limits.dailyUserDepositCap == 20000 gwei) && (limits.depositCap == 20000 gwei), "Incorrect limits");
    }
}
